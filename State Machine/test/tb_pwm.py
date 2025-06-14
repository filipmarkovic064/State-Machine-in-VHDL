''' 
tb_pwm.py V4.1 : Testbench for PWM module with fault injection. 
  By Yngve Hafting 2022, 2024 
    
  The PWM module shall connect to the PMOD H-bridge module 
  using the two signals EN and DIR. 
    EN is the enable (PWM pulse) signal 
    DIR sets the H-bridge direction 
  Ordinary checks ensure safe operation and function  
    EN should be held low while DIR changes to avoid short circuit 
    PWM period should be between 143us and 12 ms (7kHz > f > 83Hz)
    applied duty cycle should be within 5% of target duty within 2 pulses
    changes should be applied immidiately within safe limits. 
    etc. 
     
  -- The following VHDL entity is used
    entity pulse_width_modulator is
      port(
          mclk, reset  : in std_logic; 
          duty_cycle   : in std_logic_vector(7 downto 0);
          dir, en      : out std_logic);
    end entity pulse_width_modulator;
'''
import cocotb
from cocotb import start_soon
from cocotb.clock import Clock
from cocotb.handle import Force, Freeze, Release
from cocotb.triggers import ClockCycles, Edge, First, FallingEdge, RisingEdge
from cocotb.triggers import ReadOnly, ReadWrite, Timer, with_timeout  
from cocotb.utils import get_sim_time
from cocotb.result import SimTimeoutError
from cocotb.queue import Queue 

import random
import numpy as np

# Conversion to pico-seconds made easy
ps_conv = {'fs': 0.001, 'ps': 1, 'ns': 1000, 'us': 1e6, 'ms':1e9}

#design constants
PERIOD_NS = 10
PWM_TIMEOUT_MS = 12
TOO_FAST_PWM_US= 143

#check_types
RESET_TYPE = "Reset"
SHORT_CIRCUIT_TYPE = "Short circuit"
TIMEOUT_TYPE = "Timeout"
DIRECTION_TYPE = "Direction"
DUTY_CYCLE_TYPE = "Duty cycle"
REPORT_ERROR = "Report error"

class MessageQueue(Queue):
    ''' Message queue is used to store and pass assertion errors with text and traceback'''
    # colouring \033[...m  see https://stackabuse.com/how-to-print-colored-text-in-python/
    
    def clear(self):
        for i in range(self.qsize()): self.get_nowait()
            
    def put_message(self, error_type, message):
        msg = (error_type, get_sim_time('ns'), message)
        self.put_nowait(msg)

    def check_queue(self, dut):
        ''' Checks that the message queue generated by assertion errors is empty'''    
        if self.empty():
            dut._log.info("\033[1;32m No errors in found!\x1b[0m")
        else:
            while not self.empty(): 
                msg = self.get_nowait()
                dut._log.info(
                    "\033[1;31mError found: {error_type}\033[0m\033[1m @{time}ns\033[0m \n{exception}".format(
                    error_type = msg[0],
                    time = msg[1],
                    exception = str(msg[2]).split('\n')[0])) #Print only first line    
            raise msg[2]  # Provide traceback for the last error reported 

    def find_error(self, dut, error_type):
        ''' Searches for a specific error in the queue and tosses the rest'''
        if self.empty():
            raise AssertionError("NO_QUEUE")
        while (self.qsize() > 0):    
            msg = self.get_nowait()
            if msg[0] == error_type:
                dut._log.info(
                    "    Found error: {error_type} @ {time}ns... ".format(
                        error_type = msg[0],
                        time = msg[1])) 
                self.clear()
                return
        #raise only if none of the queued messages are of the correct type 
        raise AssertionError("{err} error sought, but not found!".format(err=error_type))

class SignalEventMonitor():
    """ Tracks a signal's last events.  """
    def __init__(self, signal):
        self.signal = signal
        self.last_event = get_sim_time('ps')
        self.last_rise = self.last_event
        self.last_fall = self.last_event
        start_soon(self.update())
      
    async def update(self):
        while True:
            await Edge(self.signal)
            await ReadOnly()          # ReadOnly allows edge-edge measurment
            self.last_event = get_sim_time('ps')
            if self.signal == 1: self.last_rise = self.last_event
            else: self.last_fall = self.last_event
            
    def stable_interval(self, units='ps'):
        last_event_c = self.last_event/ps_conv[units]  # convert last_event to the prefix in use
        stable = get_sim_time(units) - last_event_c    # calculate stable interval
        return stable
  
class Monitor:
    """ Contains and run all checks for signals in and out of DUT """
    def __init__(self, dut, messages):
        self.dut = dut
        self.messages = messages
        start_soon(self.run())
        
    async def run(self):
        ''' start all checks '''
        await Timer(1, 'ns')   # Settle uninitialized values
        self.dut._log.info("Starting monitoring events")
        self.en_mon  = SignalEventMonitor(self.dut.en)
        self.duty_mon = SignalEventMonitor(self.dut.duty_cycle)
        self.reset_mon = SignalEventMonitor(self.dut.reset)
        start_soon(self.check_reset())
        start_soon(self.check_short_circuit())
        start_soon(self.check_timeout())
        start_soon(self.check_direction())
        start_soon(self.check_duty_cycle())    
    
    async def check_reset(self):
        ''' Checks that PWM pulse (en) is deasserted when reset is applied '''
        while True:
            await FallingEdge(self.dut.reset) 
            try: assert self.dut.en.value == 0, "PWM enable has not been deasserted during reset"
            except AssertionError as e:
                self.messages.put_message(RESET_TYPE, e)
            self.dut._log.info("Completed: Reset test")

    async def check_short_circuit(self):
        ''' Checks that we are not short-circuiting the half-bridge by switching direction while pulsing '''
        while True:
            await Edge(self.dut.dir)
            try: 
                if self.dut.reset.value == 0:
                    assert self.dut.en.value == 0, "HALF-BRIDGE SHORT CIRCUITED: en active when changing direction"
                    assert self.en_mon.stable_interval('ns') > PERIOD_NS-1, (
                        "SHORT CIRCUIT DANGER: en deactivated less than one cycle before dir change")
                    wait_task = Timer(PERIOD_NS-1, 'ns')
                    event_task = Edge(self.dut.en)
                    result = await First(wait_task, event_task)
                    assert result == wait_task, (
                      "SHORT CICUIT DANGER: En was not stable for {per} {uni}"
                      .format(per=PERIOD_NS, uni='ns'))
            except AssertionError as e:
                self.messages.put_message(SHORT_CIRCUIT_TYPE, e)

    async def check_timeout(self):
        ''' Checks that the PWM signal is actually driven within a reasonable timeframe'''
        while True:
            if self.dut.duty_cycle.value == 0 : 
                await Edge(self.dut.duty_cycle)
            try:
                await with_timeout(Edge(self.dut.en), PWM_TIMEOUT_MS, 'ms')
            except SimTimeoutError:
                self.messages.put_message(TIMEOUT_TYPE, "PWM signal is static, TB timed out ")
                
    async def check_direction(self):
        ''' Checks that the pwm drives the motor in the correct direction'''
        while True:    
            await Edge(self.dut.duty_cycle) 
            await ClockCycles(self.dut.mclk, 2)   # Trigger two clock edges after duty cycle was changed
            await ReadOnly()                      # Wait for all signals to settle (all delta delays)
            try:
                duty = int(self.dut.duty_cycle.value.signed_integer) # Numpy compatibility 
                if np.int8(duty) > 0: 
                    assert self.dut.dir.value == 1, (
                      "DIR is not '1' within 2 clock cycles of positive duty cycle: {DU} = {D}"
                      .format(DU=np.int8(duty), D=self.dut.duty_cycle.value))
                if np.int8(duty) < 0:  
                    assert self.dut.dir.value == 0, (
                      "DIR is not '0' within 2 clock cycles of negative duty cycle: {DU} = {D}"
                      .format(DU=np.int8(duty), D=self.dut.duty_cycle.value))
            except AssertionError as e:
                self.messages.put_message(DIRECTION_TYPE, e)
                
    async def check_duty_cycle(self):
        ''' Checks that pwm pulses are not happening too fast for the PMOD module '''
        await RisingEdge(self.dut.en)
        while True:
            # Wait until we have a full period after reset
            if self.dut.reset.value == 1: 
                 await FallingEdge(self.dut.reset)
                 await RisingEdge(self.dut.en)
            await RisingEdge(self.dut.en)
            
            # Find the interval/period
            start = self.en_mon.last_rise/ps_conv['us']
            interval =  get_sim_time('us') - start
            
            try:
                # Trigger only when duty cycle has been stable for the last period
                if self.duty_mon.stable_interval('us') > interval:  
                    assert interval > TOO_FAST_PWM_US, (
                      "PWM period too short!: {iv:.2f}us, f={f:.3f}kHz   Minimum period: {per} us, ({maxf:.2f}kHz) "
                      .format(iv=interval, f=(1000/interval), per=TOO_FAST_PWM_US, maxf=(1000/TOO_FAST_PWM_US))) 
                      
                    # Calculate duty cycle   
                    mid = self.en_mon.last_fall/ps_conv['us']
                    high = mid-start
                    measured_duty = np.int8((high*100)/interval)
                    set_duty = np.int8(self.dut.duty_cycle.value.signed_integer)*100/128
                    
                    # Report duty cycle and check correspondens betweem input and output
                    sign = "-" if self.dut.dir.value == 0 else " "
                    self.dut._log.info(
                      "Duty cycles: Set dc: {S:.1f}%, Measured dc: {Sig}{M:.1f}%, period = {P:.1f}us, f = {F:.2f}kHz"
                      .format(S=set_duty, Sig = sign, M = measured_duty, P = interval, F = 1000/interval)) 
                    abs_duty = abs(set_duty)
                    deviation = np.int8(abs(abs_duty - measured_duty))
                    assert deviation < 5, (                         
                      "Set and measured duty cycle deviates by more than 5% ({D}%) "
                      .format(D=deviation))
            except AssertionError as e:
                self.messages.put_message(DUTY_CYCLE_TYPE, e)
      
class StimuliGenerator():
    ''' Generates all stimuli used in the ordinary tests '''
    def __init__(self, dut):
        self.dut = dut
        self.dut._log.info("Starting clock")
        start_soon(Clock(self.dut.mclk, PERIOD_NS, 'ns').start())
        self.dut.duty_cycle.value = 0
        start_soon(self.reset_module())

    async def reset_module(self):
        self.dut._log.info("Resetting module... ")
        self.dut.reset.value = 1
        await Timer(15, 'ns')
        self.dut.reset.value = 0
        
    async def run(self):
        self.dut._log.info("Starting duty cycle tests ")
        await Timer(20, 'ns')
        await self.fixed_duty_tests()
        self.dut._log.info("Fixed duty tests complete ")
        await self.random_duties(4)
        self.dut._log.info("Random duty tests 1/2 complete ")
        await RisingEdge(self.dut.en)
        await self.reset_module()
        self.dut._log.info("Reset between duties complete ")
        await self.random_duties(3)
        self.dut._log.info("Random duty tests 2/2 complete ")
    
    def set_duty(self, duty_cycle):
        self.dut.duty_cycle.value= int((duty_cycle*128)/100) 
    
    async def fixed_duty_tests(self):
        self.set_duty(50)
        for i in range(3): 
            await RisingEdge(self.dut.en)
        self.set_duty(-50)
        for i in range(2): 
            await RisingEdge(self.dut.en)
        
    async def random_duties(self, tests):    
        duties = list(range(-90+1,-10)) + list(range(10+1,90))
        for x in range(tests):
            random_duty = random.choice(duties)
            duties.remove(random_duty)
            self.set_duty(random_duty)
            for i in range(2): 
                await RisingEdge(self.dut.en)
        interval = random.randint(1,300)
        await Timer(interval, units='us')

@cocotb.test()
async def test_sequencer(dut):
    ''' Starts monitoring tasks and stimuli generators '''
    messages = MessageQueue()
    stimuli = StimuliGenerator(dut)
    monitor = Monitor(dut, messages)
    dut._log.info("*** STARTING ORDINARY TESTS ***")
    await stimuli.run()  
    messages.check_queue(dut)
    dut._log.info("*** ORDINARY TESTS DONE! ***")

# run after test_sequencer when using GHDL 4.0.0dev due to release not working
@cocotb.test()
async def fiat_sequencer(dut):
    ''' Starts monitoring tasks and stimuli generators '''
    messages = MessageQueue()
    fiatMonitor = Monitor(dut, messages)
    fiatStimuli = StimuliGenerator(dut)
    fiat = FaultInjector(dut, messages)  
    
    # Inject Faults to check that the testbench responds to faults
    await fiat.run()
    
class FaultInjector():
    """ Contain tests to verify that each assertion will trigger """
    def __init__(self, dut, messages):
        self.dut = dut
        self.messages = messages
        
    async def run(self):
        ''' run all FIAT tests '''
        self.dut._log.info("*** FAULT INJECTION RUNNING ***")
        
        # To test ordinary reporting: change <fault>_TYPE to REPORT_ERROR in the list
        fiat_methods = [  
            (self.reset(), RESET_TYPE), 
            (self.short_1(), SHORT_CIRCUIT_TYPE),
            (self.short_2(), SHORT_CIRCUIT_TYPE),
            (self.short_3(), SHORT_CIRCUIT_TYPE),
            (self.direction(), DIRECTION_TYPE),
            #Timeout can be omitted for demonstration purposes 
            #self.timeout(), TIMEOUT_TYPE),  
            (self.too_fast_pwm(), DUTY_CYCLE_TYPE),
            (self.duty(), DUTY_CYCLE_TYPE)]
        for each in fiat_methods: 
            await each[0]   
            if each[1] != REPORT_ERROR: 
                self.messages.find_error(self.dut, each[1])
            else: 
                self.messages.check_queue(self.dut) 
        self.dut._log.info("\x1b[1;32m Injected faults managed! \x1b[0m")
        self.dut._log.info("*** FAULT INJECTION COMPLETE ***")
        
    def release(self):  
        ''' Releases all Forced values. '''
        self.dut.reset.value = Release()
        self.dut.en.value = Release()
        self.dut.dir.value = Release()
        self.dut.duty_cycle.value = Release()
        
    
    async def disable_reset(self):
        self.dut.reset.value = Force(0)
        await Timer(20, 'ns')
   
    async def reset(self):
        ''' Enable asserted while reset is deasserted'''
        await RisingEdge(self.dut.mclk)
        self.dut._log.info("Injecting error: Enable during reset...")
        self.dut.reset.value = Force(1)
        self.dut.en.value = Force(1)
        await RisingEdge(self.dut.mclk)
        self.dut.reset.value = Force(0)
        await RisingEdge(self.dut.mclk)
        self.release()
    
    async def short_1(self):
        ''' Enable is not deasserted when dir changes'''
        self.dut._log.info("Injecting error: direction change during pulse...")
        await self.disable_reset()
        self.dut.dir.value = Force(0)
        self.dut.en.value = Force(1)
        await Timer(1, 'ns')
        self.dut.dir.value = Force(1)
        await Timer(30, 'ns')
        self.release()
        
    async def short_2(self):
        ''' Enable is deasserted within one clock cycle of dir changing''' 
        self.dut._log.info("Injecting error: pulse deassertion < 1 cycle before direction change")
        await self.disable_reset()
        self.dut.en.value = Force(1)
        await Timer(1, 'ns')
        self.dut.en.value = Force(0)
        await Timer(8, 'ns')
        self.dut.dir.value = Force(not self.dut.dir.value)
        await Timer(10, 'ns')
        self.release()
        
    async def short_3(self):
        ''' Enable asserted within one clock cycle after dir changing '''
        self.dut._log.info("Injecting error: pulse deassertion < 1 cycle after direction change")
        await self.disable_reset()
        self.dut.en.value = Force(0)
        await Timer(20, 'ns')
        self.dut.dir.value = Force(not self.dut.dir.value)
        await Timer(8, 'ns')
        self.dut.en.value = Force(1)
        await Timer(1, 'ns')
        self.release()
        
    async def timeout(self):
        ''' Prevents pulsing although a nonzero duty cycle'''
        self.dut._log.info("Injecting error: Timout -- this may take minutes...")
        await self.disable_reset()
        self.dut.duty_cycle.value = Force(0x50)
        # Stopping clock might be useful to reduce time spent here.
        # Requires a pointer/handle to the process. 
        self.dut.en.value = Force(0)
        await Timer(PWM_TIMEOUT_MS+1, 'ms')
        self.release()
        
    async def direction(self):
        ''' To not have dir correspond to duty cycle within two clock cycles'''
        self.dut._log.info("Injecting error: Too late response on direction change")
        await self.disable_reset()
        self.dut.dir.value = Freeze()
        self.dut.duty_cycle.value = Force(0xEE)
        await ClockCycles(self.dut.mclk, 3)
        self.dut.duty_cycle.value = Force(0x11)
        await ClockCycles(self.dut.mclk, 3)
        self.release()
        
    async def too_fast_pwm(self):
        ''' Runs PWM signal (en) faster than allowed by TB'''
        self.dut._log.info("Injecting error: Pulsing too fast")
        await self.disable_reset()
        for i in range(4):    
            self.dut.en.value = Force(1)    
            await RisingEdge(self.dut.mclk)
            self.dut.en.value = Force(0);
            await RisingEdge(self.dut.mclk)
        self.release()
      
    async def duty(self):
        ''' Asserts one duty cycle, and pulses another'''
        self.dut._log.info("Injecting error: Setting one duty cycle and pulsing another")
        await self.disable_reset()
        self.dut.en.value = Force(0)
        await ClockCycles(self.dut.mclk, 10)
        self.dut.duty_cycle.value = Force(-32) # 25% as hex (128 = 100%)
        await ClockCycles(self.dut.mclk, 10)
        for i in range(2):    
            self.dut.en.value = Force(1)    
            await ClockCycles(self.dut.mclk, 8001)
            self.dut.en.value = Force(0);
            await ClockCycles(self.dut.mclk, 8001)
        self.release()
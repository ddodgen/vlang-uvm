import std.stdio;
import esdl.base.core;
import esdl.base.comm;
import esdl.intf.vpi;
import esdl.data.bvec;

// vlog_startup_routines = [& initVlang, null].ptr;

extern(C) void get_handle ();

class TrafficLight: Entity
{
  // mixin(entityMixin());

  enum POLES = 4;
 private:
  Event red[POLES];
  Event yellow[POLES];
  Event green[POLES];

  Signal!(lvec!200) test;

  int count = 0;

  override public void doConfig()
  {
    timeUnit = 1.nsec;
  }

  void light() {
    // writeln(getSimTime);
    // wait((cast(Dummy) getParent).e);
    auto index = Process.self.taskIndices[0];
    if(index != 0)
      wait(green[index]);

    test.hdlBind("main.test");
    // test.hdlConnect("main");
    // test.hdlTo("main.test");
    // test.hdlFrom("main.test");
    // writeln("Time unit is: ", timeUnit());
    while(true)
      {
	lockStage();
	test = cast(lvec!200) (test + 7);
	// writeln("Test is: ", test);
  	// writeln(getSimTime, ": Red -> Green ", index, " -- ",
	// Process.self.getFullName());
  	yellow[index].notify(20);
	// writeln("I am here: ", index);
  	red[index].notify(25);
  	wait(yellow[index]);
	// writeln("Green -> Yellow ", index);
  	wait(red[index]);
  	// writeln("Yellow -> Red ", index);
  	green[(index + 1)%POLES].notify();
  	wait(green[index]);
	synchronized(this) {
	  ++count;
	}
      }
  }
  public int x;
  // Task!("light()",0)  tLightTT[POLES];
  Task!light  tLightTT[POLES];

}

class TrafficLightWrapper: TrafficLight {}

class Dummy: Entity
{
  // Event e;
  // void etrigger()
  // {
  //   wait(990.nsec);
  //   e.notify();
  // }
  // Task!(etrigger, 0) trigE;

  private TrafficLightWrapper traffic;
}

class TrafficRoot: RootEntity
{ 
  @parallelize Inst!Dummy dummy;

  this(string name) {
    super(name);
  }

  override void doConfig() {
    // writeln("Configuring TrafficLight");
    if(this.getName == "theRoot") {
      timeUnit = 100.psec;
      timePrecision = 10.psec;
      // threadCount = 4;
    } else {
      timeUnit = 1000.psec;
      timePrecision = 100.psec;
      // threadCount = 4;
    }      
  }
}

static import core.runtime;
extern (C) void hellod() {
  // rt_init(0);
  import std.stdio;
  writeln("Hello World from D");
  // theRoot.elaborate();
  // for (size_t i=1; i!=1000; ++i) {
  //   // theRoot.forkSim(i.nsec);
  //   // theRoot.joinSim();
  //   simulateAllRoots(i.nsec);
  //   // theRoot.simulate(i.nsec);
  // }
  // theRoot.terminate();
}

extern(C) void initEsdl() {
  import core.runtime;  
  Runtime.initialize();
  hello_register();

  TrafficRoot theRoot = new TrafficRoot("theRoot");
  theRoot.forkElab();
  theRoot.joinElab();

  s_cb_data new_cb;
  new_cb.reason = vpiCbStartOfSimulation;
  new_cb.cb_rtn = &callback_cbNextSimTime;//next callback address
  // new_cb.time = null;
  // new_cb.obj = null;
  // new_cb.value = null;
  // new_cb.user_data = null;
  vpiRegisterCb(&new_cb);

  s_cb_data end_cb;
  new_cb.reason = vpiCbEndOfSimulation;
  new_cb.cb_rtn = &callback_cleanup;//next callback address
  // new_cb.time = null;
  // new_cb.obj = null;
  // new_cb.value = null;
  // new_cb.user_data = null;
  vpi_register_cb(&new_cb);

  auto precision = vpi_get(vpiTimePrecision, null);
  auto unit = vpi_get(vpiTimeUnit, null);
  writeln("precision: ", precision, " unit: ", unit);

  writeln(vpi_get_args());

}


int hello_compiletf(char*user_data) {
  return 0;
}

int hello_calltf(char*user_data) {
  writeln("Hello, World!");
  hellod();
  return 0;
}

void hello_register()
{
  import std.string;
  s_vpi_systf_data tf_data;

  tf_data.type      = vpiSysTask;
  tf_data.tfname    = cast(char*) "$hello".toStringz();
  tf_data.calltf    = &hello_calltf;
  tf_data.compiletf = &hello_compiletf;
  tf_data.sizetf    = null;
  tf_data.user_data = null;
  vpi_register_systf(&tf_data);
}

int callback_cbNextSimTime(p_cb_data cb) {
  s_vpi_time  now;
  now.type = vpiSimTime;
  vpi_get_time(null, &now);
  long time = now.high;
  time <<= 32;
  time += now.low;

  // writefln("callback_cbNextSimTime time=%d", time);

  simulateAllRoots(time.nsec);

  s_cb_data new_cb;
  new_cb.reason = vpiCbReadOnlySynch;
  new_cb.cb_rtn = &callback_cbReadOnlySynch;//next callback address
  new_cb.time = &now;
  new_cb.obj = null;
  new_cb.value = null;
  new_cb.user_data = null;
  vpi_register_cb(&new_cb);
  return 0;
}

int callback_cbReadOnlySynch(p_cb_data cb) {
  s_vpi_time  now;
  now.type = vpiSimTime;
  vpi_get_time(null, &now);
  // writefln("callback_cbReadOnlySync time=%d", now.low);

  s_cb_data new_cb;
  new_cb.reason = vpiCbNextSimTime;
  new_cb.cb_rtn = &callback_cbNextSimTime;//next callback address
  new_cb.time = null;
  new_cb.obj = null;
  new_cb.value = null;
  new_cb.user_data = null;
  vpi_register_cb(&new_cb);
  return 0;
}

int callback_cleanup(p_cb_data cb) {
  terminateAllRoots();
  import core.runtime;  
  Runtime.terminate();
  return 0;
}

import std.conv;

public string[][] vpi_get_args() {
  s_vpi_vlog_info info;
  string[] argv;
  string[][] argvs;

  vpi_get_vlog_info(&info);

  auto vlogargv = info.argv;
  auto vlogargc = info.argc;

  if(vlogargv is null) return argvs;

  for (size_t i=0; i != vlogargc; ++i) {
    char* vlogarg = *(vlogargv+i);
    string arg;
    arg = (vlogarg++).to!string;
    if(arg == "-f" || arg == "-F") {
      argvs ~= argv;
      argv.length = 0;
    }
    else {
      argv ~= arg;
    }
  }
  argvs ~= argv;
  return argvs;
}

void main(){}

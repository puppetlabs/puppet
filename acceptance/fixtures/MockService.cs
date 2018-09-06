/*

The MockService is a C# class representing a stubbed service. We will
compile this class into the service's .exe file.

Here, we implement four methods:
    * OnStart    -- called when SCM starts the service
    * OnPause    -- called when SCM pauses the service
    * OnContinue -- called when SCM resumes a paused service
    * OnStop     -- called when SCM stops a service

Before calling one of these 'On' methods, the ServiceBase class sets
the service state to the corresponding PENDING state. The service state
is in this PENDING state until the 'On' method is finished, whereby it is
then transitioned into the corresponding final state. Thus if we sleep for a
few seconds in the 'On' method, then note that SCM will report our service
state as being in the PENDING state while we're asleep. For example, if the
'On' method is 'OnStart', the service state is set to START_PENDING before
calling 'OnStart', is START_PENDING while executing 'OnStart', and then is set
to RUNNING after exiting 'OnStart'.

When testing the Windows service provider, we really want to test to ensure
that it handles the state transitions correctly. For example, we want to
check that:
    * It waits for the appropriate PENDING state to finish
    * It sets the service state to the appropriate final state

The reason we want to do this is because our service provider is communicating
with SCM directly, which does not care how the service implements these
transitions so long as it implements them. C#'s ServiceBase class implements
these state transitions for us. Thus by going to sleep in all of our 'On' methods,
we simulate transitioning to the corresponding PENDING state. When we wake-up
and exit the 'On' method, we will transition to the appropriate final state.

NOTE: Normally, you're supposed to have the service thread in a separate process.
The 'On' methods in this class would send signals to the service thread and then wait
for those signals to be processed. Sending and waiting for these signals is quite
hard and unnecessary for our use-case, which is why our MockService does not have
the service thread.

*/

using System;
using System.ServiceProcess;

public class MockService : ServiceBase {
  public static void Main() {
    System.ServiceProcess.ServiceBase.Run(new MockService());
  }

  public MockService() {
    ServiceName = "%{service_name}";
    CanStop = true;
    CanPauseAndContinue = true;
  }

  private void StubPendingTransition(int seconds) {
    RequestAdditionalTime(2000);
    System.Threading.Thread.Sleep(seconds * 1000);
  }

  protected override void OnStart(string [] args) {
    StubPendingTransition(%{start_sleep});
  }

  protected override void OnPause() {
    StubPendingTransition(%{pause_sleep});
  }

  protected override void OnContinue() {
    StubPendingTransition(%{continue_sleep});
  }

  protected override void OnStop() {
    StubPendingTransition(%{stop_sleep});
  }
}

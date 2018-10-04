/*

The MockUninstaller is a C# class representing a stubbed exe uninstaller. We will
compile this class into an usable .exe file.

A MockInstaller _MUST_ come alongside a MockUninstaller, so we can uninstall the
fake package from the system

*/
using System;

public class MockInstaller
{   public static void Main()
   {
        try
        {
            %{uninstall_commands}
        }
        catch {
            Environment.Exit(1003);
        }
        string keyName = "Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall";
        Console.WriteLine("Uninstalling...");
        /*
            Remove the entire registry key created by the installer exe
         */
        using (Microsoft.Win32.RegistryKey _key = Microsoft.Win32.Registry.LocalMachine.OpenSubKey(keyName, true))
        {
            _key.DeleteSubKeyTree("%{package_display_name}");
        }
   }
}

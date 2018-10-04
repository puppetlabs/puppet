/*

The MockInstaller is a C# class representing a stubbed exe installer. We will
compile this class into an installable .exe file.

A MockInstaller _MUST_ come alongside a MockUninstaller, so we can uninstall the
fake package from the system

*/
using System;

public class MockInstaller
{   public static void Main()
   {
        try
        {
            %{install_commands}
        }
        catch {
            Environment.Exit(1003);
        }
        string keyName = "Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall";
        Microsoft.Win32.RegistryKey key;
        key = Microsoft.Win32.Registry.LocalMachine.CreateSubKey(keyName + "\\%{package_display_name}");
        /*
            Puppet deems an exe package 'installable' by identifying whether or not the following registry
            values exist in the Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\PackageName key:

            * DisplayName
            * DisplayVersion
            * UninstallString

            So we must set those values in the registry for this to be an 'installable package' manageable by
            puppet.
         */
        key.SetValue("DisplayName", "%{package_display_name}");
        key.SetValue("DisplayVersion", "1.0.0");
        key.SetValue("UninstallString", @"%{uninstaller_location}");
        key.Close();
        Console.WriteLine("Installing...");
   }
}

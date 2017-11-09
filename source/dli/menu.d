module dli.menu;

public import dli.menu_item;
public import dli.welcome_msg_display_scenario;

import std.exception;
import std.range.interfaces;
import std.range.primitives;

public abstract class Menu(inputStreamT, outputStreamT)
{
    protected inputStreamT inputStream;
    protected outputStreamT outputStream;

    private string welcomeMsg; // Welcome message for this menu
    private string welcomeMsgEnding = "\n"; // Ending for the welcome message, acts as separator with the menu items
    private WelcomeMsgDisplayScenario welcomeMsgDisplayScenario; // Scenario when the welcome message should be displayed

    private MenuStatus status = MenuStatus.Stopped;

    // Starts the menu. This method can only be called if the menu is stopped.
    public void run()
    {
        enforce(status == MenuStatus.Stopped);
        try
        {
            status = MenuStatus.Running;

            printWelcomeMsgAndEnding();
            printItems();
            promptForSelection();
        }
        finally
        {
            status = MenuStatus.Stopped;
        }
    }

    private void promptForSelection()
    {
        parseUserSelection(inputStream.readln()[0..$-1]); // Important to remove EOL character
    }

    private void printWelcomeMsgAndEnding()
    {
        outputStream.write(welcomeMsg);
        outputStream.write(welcomeMsgEnding);
    }

    abstract protected void printItems();
    abstract protected void parseUserSelection(string input);

    public void setWelcomeMsg(string msg,
            WelcomeMsgDisplayScenario displayScenario = WelcomeMsgDisplayScenario.Always)
    in
    {
        assert(msg !is null);
    }
    body
    {
        welcomeMsg = msg;
        welcomeMsgDisplayScenario = displayScenario;
    }
}

private enum MenuStatus
{
    Stopped,
    Running,
    Paused
}

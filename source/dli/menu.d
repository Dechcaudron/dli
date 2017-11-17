module dli.menu;

public import dli.menu_item;
import dli.i_menu_item;
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

    private Status _status = Status.Stopped;

    protected alias exitMenuItemT = MenuItem!(void delegate() pure nothrow @nogc @safe);

    @property
    protected Status status()
    {
        return _status;
    }

    // Starts the menu. This method can only be called if the menu is stopped.
    public void run()
    {
        enforce(_status == Status.Stopped);
        try
        {
            _status = Status.Starting;
            addExitMenuItem(createMenuItem("Exit", {_status = Status.Stopping;}));

            _status = Status.Running;

            while(_status == Status.Running)
            {
                printWelcomeMsg();
                printEnabledItems();
                awaitAndExecuteUserInteraction();
            }
        }
        finally
        {
            _status = Status.Stopping;
            removeExitMenuItem();
            _status = Status.Stopped;
        }
    }

    private void awaitAndExecuteUserInteraction()
    {
        string cleansedUserInput = inputStream.readln()[0..$-1]; // Important to remove EOL character
        auto menuItem = getMenuItemFromUserInput(cleansedUserInput);
        menuItem.execute();
    }

    private void printWelcomeMsg()
    {
        outputStream.write(welcomeMsg);
        outputStream.write(welcomeMsgEnding);
    }

    abstract protected void printEnabledItems();
    abstract protected IMenuItem getMenuItemFromUserInput(string input);
    abstract protected void addExitMenuItem(exitMenuItemT exitMenuItem);
    abstract protected void removeExitMenuItem();

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

    protected enum Status
    {
        Stopping,
        Stopped,
        Starting,
        Running
    }
}

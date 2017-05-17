module dli.menu;

public import dli.menu_item;
public import dli.welcome_msg_display_scenario;

import std.exception;
import std.range.interfaces;
import std.range.primitives;

public abstract class Menu(inputRangeT, outputRangeT)
        if (isInputRange!inputRangeT && isOutputRange!outputRangeT
            && is(ElementType!inputRangeT == dchar) && is(ElementType!outputRangeT == dchar))
{
    protected inputRangeT inputRange;
    protected outputRangeT outputRange;

    private string welcomeMsg; /// Welcome message for this menu
    private string welcomeMsgEnding = "\n"; /// Ending for the welcome message, acts as separator with the menu items
    private WelcomeMsgDisplayScenario welcomeMsgDisplayScenario; /// Scenario when the welcome message should be displayed

    private MenuStatus status = MenuStatus.Stopped;

    /// Starts the menu. This method can only be called if the menu is stopped.
    public void startMenu()
    {
        enforce(status == MenuStatus.Stopped);

        printWelcomeMsgAndEnding();
        printMenuItems();
    }

    private void printWelcomeMsgAndEnding()
    {
        
    }

    abstract protected void printMenuItems();

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

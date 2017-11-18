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

    private string promptMsg = "> "; // String to be printed before asking the user for input
    private string afterExecutionMsg = "\n"; // String to be printed after any menu item is executed. Generally, you will want this to be EOL.
    private string exitMsg = "Exiting menu...";

    private Status _status = Status.Stopped;

    protected alias exitMenuItemT = MenuItem!(void delegate() @safe);

    @property
    protected Status status()
    {
        return _status;
    }

    mixin(generateMsgSetterProperty(__traits(identifier, welcomeMsg)));
    mixin(generateMsgSetterProperty(__traits(identifier, promptMsg)));
    mixin(generateMsgSetterProperty(__traits(identifier, exitMsg)));

    // Starts the menu. This method can only be called if the menu is stopped.
    public void run()
    {
        enforce(_status == Status.Stopped);
        try
        {
            _status = Status.Starting;
            /* Before actually starting the menu, we need to provide the user with a way to
               exit the menu. We create an ad hoc MenuItem for this purpose and add it here */
            addExitMenuItem(createMenuItem("Exit", 
                {
                    outputStream.writeln(exitMsg);
                    _status = Status.Stopping;}));

            _status = Status.Running;

            while(_status == Status.Running)
            {
                printWelcomeMsg();

                printEnabledItems();
                outputStream.write(promptMsg);
                awaitAndExecuteUserInteraction();
                outputStream.write(afterExecutionMsg);
            }
        }
        finally
        {
            _status = Status.Stopping;
            // In order to leave things as they were prior to calling this method, the ad hoc MenuItem used to exit the menu is removed
            removeExitMenuItem();
            _status = Status.Stopped;
        }
    }

    private void awaitAndExecuteUserInteraction()
    {
        import std.string : strip;

        // Note that we are calling strip here to remove the EOL chars, but at some point we may want to allow
        // someone to type leading or trailing whitespaces which they don't want removed. This will do for now.
        string cleansedUserInput = strip(inputStream.readln());
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

    protected enum Status
    {
        Stopping,
        Stopped,
        Starting,
        Running
    }
}

// Helper function to generate setters via mixins
private string generateMsgSetterProperty(string fieldName) pure
{
    import std.format : format;
    import std.uni : toUpper;
    import std.conv : to;

    string capitalizedFieldName = to!string(toUpper(fieldName[0])) ~ fieldName[1..$];

    return format("@property
                   public void %s(string s)
                   in{ assert(s !is null);}
                   body
                   {
                       enforce(_status == Status.Stopped);
                       %s = s;
                   }", capitalizedFieldName, fieldName);
}


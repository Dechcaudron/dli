module dli.menu;

public import dli.menu_item;
public import dli.display_scenario;
import dli.i_menu_item;
import dli.exceptions.invalid_item_exception;

import std.exception;
import std.range.interfaces;
import std.range.primitives;

public abstract class Menu(inputStreamT, outputStreamT)
{
    protected inputStreamT inputStream;
    protected outputStreamT outputStream;

    private string _welcomeMsg; // Welcome message for this menu
    private DisplayScenario _welcomeMsgDisplayScenario; // Scenario when the welcome message should be displayed

    private string _promptMsg = "> "; // String to be printed before asking the user for input
    private string _onItemExecutedMsg = "\n"; // String to be printed after any menu item is executed. Generally, you will want this to be EOL.
    private string _onMenuExitMsg = "Exiting menu...";
    private string _onInvalidItemSelectedMsg = "Please, select a valid item from the list.";

    public static enum printItemIdKeyword = "_$_ID_$_"; /// String to be used in place of the IMenuItem identifier in itemPrintFormat
    public static enum printItemTextKeyword = "_$_TEXT_$_"; /// String to be used in place of the IMenuItem text in itemPrintFormat
    private string _itemPrintFormat = printItemIdKeyword ~ " - " ~ printItemTextKeyword;

    private Status _status = Status.Stopped;

    protected alias exitMenuItemT = MenuItem!(void delegate() @safe);

    @property
    protected Status status()
    {
        return _status;
    }

    mixin(generateMenuCustomizingSetter!string(__traits(identifier, _welcomeMsg)));
    mixin(generateMenuCustomizingSetter!DisplayScenario(__traits(identifier, _welcomeMsgDisplayScenario)));
    mixin(generateMenuCustomizingSetter!string(__traits(identifier, _promptMsg)));
    mixin(generateMenuCustomizingSetter!string(__traits(identifier, _onMenuExitMsg)));
    mixin(generateMenuCustomizingSetter!string(__traits(identifier, _onInvalidItemSelectedMsg)));
    mixin(generateMenuCustomizingSetter!string(__traits(identifier, _itemPrintFormat)));

    /// Starts the menu. This method can only be called if the menu is stopped.
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
                    outputStream.writeln(_onMenuExitMsg);
                    _status = Status.Stopping;}));

            _status = Status.Running;

            while(_status == Status.Running)
            {
                printWelcomeMsg();

                printEnabledItems();
                outputStream.write(_promptMsg);
                try
                {
                    awaitAndExecuteUserInteraction();
                }
                catch(InvalidItemException e)
                {
                    outputStream.writeln(_onInvalidItemSelectedMsg);
                }
                outputStream.write(_onItemExecutedMsg);
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

    protected void printItem(string id, string itemText)
    {
        import std.string : replace;

        string toBePrinted = _itemPrintFormat.replace(printItemIdKeyword, id).
                             replace(printItemTextKeyword, itemText);
        outputStream.writeln(toBePrinted);
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
        outputStream.writeln(_welcomeMsg);
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
private string generateMenuCustomizingSetter(T)(string fieldName) pure
in
{
    assert(fieldName[0] == '_');
}
body
{
    import std.format : format;
    import std.uni : toUpper;
    import std.conv : to;

    string propertyIdentifier = fieldName[1..$];

    return format("@property
                   public void %s(%s a)
                   body
                   {
                       enforce(_status == Status.Stopped);

                       %s = a;
                   }", propertyIdentifier, T.stringof, fieldName);
}


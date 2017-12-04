module dli.menu;

public import dli.menu_items.simple_menu_item;
public import dli.display_scenario;
import dli.exceptions.invalid_item_exception;

import std.exception;
import std.range.interfaces;
import std.range.primitives;
import std.typecons : Tuple, tuple;

public abstract class Menu(inputStreamT, outputStreamT, keyT)
{
    protected inputStreamT inputStream;
    protected outputStreamT outputStream;

    protected MenuItem[keyT] menuItems;

    private string _welcomeMsg = "Please, select an option:"; // Welcome message for this menu
    private DisplayScenario _welcomeMsgDisplayScenario; // Scenario when the welcome message should be displayed

    private string _promptMsg = "> "; // String to be printed before asking the user for input
    private string _onItemExecutedMsg = "\n"; // String to be printed after any menu item is executed. Generally, you will want this to be EOL.
    private string _onMenuExitMsg = "Exiting menu...";
    private string _onInvalidItemSelectedMsg = "Please, select a valid item from the list.";

    public static enum printItemIdKeyword = "_$_ID_$_"; /// String to be used in place of the MenuItem identifier in itemPrintFormat
    public static enum printItemTextKeyword = "_$_TEXT_$_"; /// String to be used in place of the MenuItem text in itemPrintFormat
    private string _itemPrintFormat = printItemIdKeyword ~ " - " ~ printItemTextKeyword; /// Stores the format in which menu items are printed to the output stream

    private Status _status = Status.Stopped;

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
            addExitMenuItem(createSimpleMenuItem("Exit", 
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

    /// Removes the menu item associated with key. If no item was associated with such key, nothing happens.
    public void removeItem(keyT key)
    {
        enforce(status is Status.Stopped);

        menuItems.remove(key);
    }

    /// Removes all items from this menu.
    public void removeAllItems()
    {
        enforce(status is Status.Stopped);

        menuItems.clear();
    }

    /// Associates the given item with the given key in this menu.
    public void addItem(MenuItem item, keyT key)
    in
    {
        assert(item !is null);
    }
    body
    {
        enforce(status is Status.Stopped);
        enforce(key !in menuItems);

        menuItems[key] = item;
    }

    private void printEnabledItems()
    {
        import std.conv : to;

        void printItem(string key, string itemText)
        {
            import std.string : replace;

            string toBePrinted = _itemPrintFormat.replace(printItemIdKeyword, key).
                                replace(printItemTextKeyword, itemText);
            outputStream.writeln(toBePrinted);
        }

        foreach(Tuple!(keyT, MenuItem) itemTuple; sortItemsForDisplay())
            if(itemTuple[1].enabled)
                printItem(to!string(itemTuple[0]), itemTuple[1].displayString);
    }

    private void awaitAndExecuteUserInteraction()
    {
        import std.string : strip;
        import std.format : format;
        import std.conv : to, ConvException;

        // Note that we are calling strip here to remove the EOL chars, but at some point we may want to allow
        // someone to type leading or trailing whitespaces which they don't want removed. This will do for now.
        string cleansedUserInput = inputStream.readln().strip();
        keyT menuItemKey;
        try
        {
            menuItemKey = to!keyT(cleansedUserInput);
        }
        catch(ConvException e)
        {
            // TODO: throw an InvalidInputException?
            throw new InvalidItemException(format!("Cannot convert user input '%s' " ~
                "into key type %s")(cleansedUserInput, keyT.stringof));
        }
        
        MenuItem menuItem = getMenuItem(menuItemKey);
        enforce!InvalidItemException(menuItem.enabled, format!("User tried to select disabled " ~
                "menu item with key %s")(menuItemKey));
        
        menuItem.execute();
    }

    private void printWelcomeMsg()
    {
        outputStream.writeln(_welcomeMsg);
    }

    protected final MenuItem getMenuItem(keyT key)
    {
        import std.format : format;
        enforce!InvalidItemException(key in menuItems, format!("Tried to retrieve " ~
                "unexisting menu item with key %s")(key));

        return menuItems[key];
    }

    protected Tuple!(keyT, MenuItem)[] sortItemsForDisplay()
    {
        //Default implementation simply returns the items as they are found in menuItems
        Tuple!(keyT, MenuItem)[] sortedItems;

        foreach(keyT key, MenuItem item; menuItems)
            sortedItems ~= tuple(key, item);

        return sortedItems;
    }

    abstract protected void addExitMenuItem(MenuItem exitMenuItem);
    abstract protected void removeExitMenuItem();

    protected enum Status
    {
        Stopping,
        Stopped,
        Starting,
        Running
    }

    // Helper function to generate setters via mixins
    private static string generateMenuCustomizingSetter(T)(string fieldName) pure
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
}

public abstract class MenuItem
{
    immutable string displayString;

    private bool _enabled;

    @property
    public bool enabled()
    {
        return _enabled;
    }

    @property
    protected void enabled(bool enable)
    {
        _enabled = enable;
    }

    this(string displayString, bool enabled)
    {
        this.displayString = displayString;
        this.enabled = enabled;
    }

    protected abstract void execute();
}


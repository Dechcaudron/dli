module dli.index_menu;

import std.stdio;
import std.exception;
import std.conv;

import dli.menu;
import dli.exceptions.invalid_item_exception;

import std.typecons : Tuple, tuple;

public class IndexMenu(inputStreamT, outputStreamT) : TextMenu!(inputStreamT, outputStreamT, size_t)
{
    private size_t highestMenuItemIndex;

    public this(inputStreamT inStream, outputStreamT outStream)
    {
        inputStream = inStream;
        outputStream = outStream;
    }

    public override void addItem(MenuItem item, size_t key)
    {
        super.addItem(item, key);

        import std.algorithm.comparison : max;

        highestMenuItemIndex = max(highestMenuItemIndex, key);
    }

    /// Adds the given item, automatically assigning the next highest available key
    public void addItem(MenuItem item)
    {
        addItem(item, highestMenuItemIndex + 1);
    }

    protected override void addExitMenuItem(MenuItem exitMenuItem)
    {
        menuItems[highestMenuItemIndex + 1] = exitMenuItem;
    }

    protected override void removeExitMenuItem()
    {
        menuItems.remove(highestMenuItemIndex + 1);
    }

    protected override Tuple!(size_t, MenuItem)[] sortItemsForDisplay()
    {
        // It is important that the items are printed in the correct order
        import std.algorithm.sorting : sort;
        auto sortedKeys = sort(menuItems.keys);

        Tuple!(size_t, MenuItem)[] sortedItems;

        foreach(size_t menuItemIndex; sortedKeys)
            sortedItems ~= tuple(menuItemIndex, menuItems[menuItemIndex]);

        return sortedItems;        
    }
}

public auto createIndexMenu(File inStream = stdin, File outStream = stdout)
{
    return new IndexMenu!(File, File)(inStream, outStream);
}

public auto createIndexMenu(inputStreamT, outputStreamT)(inputStreamT inStream, outputStreamT outStream)
{
    return new IndexMenu!(inputStreamT, outputStreamT)(inStream, outStream);
}

// TESTS
version(unittest)
{
    import dli.input_string_stream;
    import dli.output_string_stream;
    import test.dli.mock_menu_item;

    @("Test IndexMenu.addItem(MenuItem) properly places items")
    unittest
    {
        auto inputStream = new shared InputStringStream();
        auto menu = createIndexMenu(inputStream, new shared OutputStringStream());
        auto item1 = new MockMenuItem();
        auto item2 = new MockMenuItem();
        // We deliberately skip item 3
        auto item4 = new MockMenuItem();
        auto item5 = new MockMenuItem();

        menu.addItem(item1);
        menu.addItem(item2);
        menu.addItem(item4, 4); // This one we specify the key
        menu.addItem(item5);

        inputStream.appendLine("1");
        inputStream.appendLine("2");
        inputStream.appendLine("6"); // 6 should correspond to the exit menu item
        menu.run();

        assert(item1.executed);
        assert(item2.executed);
        assert(!item4.executed);
        assert(!item5.executed);

        inputStream.appendLine("4");
        inputStream.appendLine("5");
        inputStream.appendLine("6");
        menu.run();

        assert(item4.executed);
        assert(item5.executed);
    }
}
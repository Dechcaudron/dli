module dli.index_menu;

import std.stdio;
import std.exception;
import std.conv;

import dli.menu;
import dli.exceptions.invalid_item_exception;
import dli.i_menu_item;

import std.typecons;

public class IndexMenu(inputStreamT, outputStreamT) : Menu!(inputStreamT, outputStreamT)
{
    private IMenuItem[size_t] menuItems;
    private size_t highestMenuItemIndex;

    public this(inputStreamT inStream, outputStreamT outStream)
    {
        inputStream = inStream;
        outputStream = outStream;
    }

    public void addItem(IMenuItem item, size_t itemIndex)
    in
    {
        assert(item !is null);
    }
    body
    {
        enforce(itemIndex !in menuItems);
        enforce(status is Status.Stopped);

        import std.algorithm.comparison : max;


        menuItems[itemIndex] = item;
        highestMenuItemIndex = max(highestMenuItemIndex, itemIndex);
    }

    public void removeAllItems()
    {
        enforce(status is Status.Stopped);

        menuItems.clear();
        highestMenuItemIndex = 0;
    }

    protected override void addExitMenuItem(IMenuItem exitMenuItem)
    {
        enforce(status is Status.Starting);

        menuItems[highestMenuItemIndex + 1] = exitMenuItem;
    }

    protected override void removeExitMenuItem()
    {
        enforce(status is Status.Stopping);

        menuItems.remove(highestMenuItemIndex + 1);
    }

    protected override void printEnabledItems()
    {
        // It is important that the items are printed in the correct order
        import std.algorithm.sorting : sort;
        auto sortedKeys = sort(menuItems.keys);

        foreach(size_t menuItemIndex; sortedKeys)
        {
            auto item = menuItems[menuItemIndex];
            if (item.enabled)
                printItem(to!string(menuItemIndex), item.text);
        }
    }

    protected override IMenuItem getMenuItemFromUserInput(string input)
    in
    {
        assert(input !is null);
    }
    body
    {
        size_t chosenItemIndex = to!size_t(input);

        enforce!InvalidItemException(chosenItemIndex in menuItems &&
                menuItems[chosenItemIndex].enabled);

        return menuItems[chosenItemIndex];
    }
}

public auto createIndexMenu(inputStreamT, outputStreamT)(inputStreamT inStream = stdin, outputStreamT outStream = stdout)
{
    return new IndexMenu!(inputStreamT, outputStreamT)(inStream, outStream);
}
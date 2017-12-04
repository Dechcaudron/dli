module dli.index_menu;

import std.stdio;
import std.exception;
import std.conv;

import dli.menu;
import dli.exceptions.invalid_item_exception;

import std.typecons : Tuple, tuple;

public class IndexMenu(inputStreamT, outputStreamT) : Menu!(inputStreamT, outputStreamT, size_t)
{
    private size_t highestMenuItemIndex;

    public this(inputStreamT inStream, outputStreamT outStream)
    {
        inputStream = inStream;
        outputStream = outStream;
    }

    public override void addItem(MenuItem item, size_t itemIndex)
    {
        super.addItem(item, itemIndex);

        import std.algorithm.comparison : max;

        highestMenuItemIndex = max(highestMenuItemIndex, itemIndex);
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

public auto createIndexMenu(inputStreamT, outputStreamT)(inputStreamT inStream = stdin, outputStreamT outStream = stdout)
{
    return new IndexMenu!(inputStreamT, outputStreamT)(inStream, outStream);
}
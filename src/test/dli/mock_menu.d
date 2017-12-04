module test.dli.mock_menu;

import dli.menu;
import dli.input_string_stream;
import dli.output_string_stream;

public class MockMenu : Menu!(shared InputStringStream, shared OutputStringStream, size_t)
{
    private enum size_t exitMenuItemKey = size_t.max;

    public void mock_writeln(string s)
    in
    {
        assert(s !is null);
    }
    body
    {
        inputStream.appendLine(s);
    }

    public void mock_writeExitRequest()
    {
        import std.conv : to;

        inputStream.appendLine(to!string(exitMenuItemKey));
    }

    this()
    {
        inputStream = new shared InputStringStream();
        outputStream = new shared OutputStringStream();
    }

    this(shared InputStringStream inputStream, shared OutputStringStream outputStream)
    {
        inputStream = inputStream;
        outputStream = outputStream;
    }

    protected override void addExitMenuItem(MenuItem exitMenuItem)
    {
        menuItems[exitMenuItemKey] = exitMenuItem;
    }

    protected override void removeExitMenuItem()
    {
        menuItems.remove(exitMenuItemKey);
    }
}
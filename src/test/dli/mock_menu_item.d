module test.dli.mock_menu_item;

import dli.menu : MenuItem;

///
public class MockMenuItem : MenuItem
{
    private bool _executed;

    /// Whether the item has been executed or not.
    @property
    public bool executed() const
    {
        return _executed;
    }

    ///
    this(string displayString = "mockMenuItem", bool enabled = true)
    {
        super(displayString, enabled);
    }

    protected override void execute()
    {
        _executed = true;
    }
}
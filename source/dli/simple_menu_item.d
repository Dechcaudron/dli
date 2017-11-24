module dli.simple_menu_item;

import dli.i_menu_item;

public class SimpleMenuItem(actionT) : IMenuItem
{
    private string _text;
    private bool _enabled;
    private actionT action;

    @property
    public string text()
    {
        return _text;
    }

    @property
    public bool enabled()
    {
        return _enabled;
    }

    @property
    public void enabled(bool enable)
    {
        _enabled = enable;
    }

    public this(string text, actionT action, bool enabled = true)
    {
        _text = text;
        _enabled = enabled;
        this.action = action;
    }

    public void execute()
    {
        action();
    }
}

public auto createSimpleMenuItem(actionT)(string text, actionT action, bool enabled = true)
{
    return new SimpleMenuItem!actionT(text, action, enabled);
}
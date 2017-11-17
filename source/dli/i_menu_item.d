module dli.i_menu_item;

public interface IMenuItem
{
    @property
    string text();
    @property
    bool enabled();
    @property
    void enabled(bool enable);

    void execute();
}
module dli.menu_items.simple_menu_item;

import dli.menu;


public class SimpleMenuItem(actionT) : MenuItem
{
    private actionT action;

    public this(string displayString, actionT action, bool enabled = true)
    {
        super(displayString, enabled);
        this.action = action;
    }

    override void execute()
    {
        action();
    }
}

/// Helper function to create an instance of SimpleMenuItem
public auto createSimpleMenuItem(actionT)(string displayString, actionT action, bool enabled = true)
{
    return new SimpleMenuItem!actionT(displayString, action, enabled);
}

// TESTS

@("Test SimpleMenuItem can call functions with no arguments")
unittest
{
    import test.dli.mock_menu : MockMenu;
    import std.conv : to;

    bool f1WasCalled;
    void f1() 
    {
        f1WasCalled = true;
    }

    MockMenu menu = new MockMenu();    
    MenuItem f1Caller = createSimpleMenuItem("f1Caller", &f1);

    menu.addItem(f1Caller, 1);
    menu.mock_writeln("1");
    menu.mock_writeln(to!string(MockMenu.exitMenuItemKey));
    menu.run();

    assert(f1WasCalled);

    bool lambdaWasCalled;
    MenuItem lambdaCaller = createSimpleMenuItem("lambdaCaller", {lambdaWasCalled = true;});

    menu.addItem(lambdaCaller, 2);
    menu.mock_writeln("2");
    menu.mock_writeln(to!string(MockMenu.exitMenuItemKey));
    menu.run();

    assert(lambdaWasCalled);
}

@("Test SimpleMenuItem can call methods with no arguments")
unittest
{
    import test.dli.mock_menu : MockMenu;
    import std.conv : to;
    
    struct TestStruct
    {
        bool methodWasCalled;
        void method()
        {
            methodWasCalled = true;
        }
    }

    MockMenu menu = new MockMenu();
    TestStruct testStructInstance;
    MenuItem structMethodCaller = createSimpleMenuItem("structMethodCaller", &testStructInstance.method);

    menu.addItem(structMethodCaller, 1);
    menu.mock_writeln("1");
    menu.mock_writeln(to!string(MockMenu.exitMenuItemKey));
    menu.run();

    assert(testStructInstance.methodWasCalled);

    class TestClass
    {
        bool methodWasCalled;
        void method()
        {
            methodWasCalled = true;
        }
    }

    TestClass testClassInstance = new TestClass();
    MenuItem classMethodCaller = createSimpleMenuItem("classMethodCaller", &testClassInstance.method);

    menu.addItem(classMethodCaller, 2);
    menu.mock_writeln("2");
    menu.mock_writeln(to!string(MockMenu.exitMenuItemKey));
    menu.run();

    assert(testClassInstance.methodWasCalled);
}
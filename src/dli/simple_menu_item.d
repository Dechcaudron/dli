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

/// Helper function to create an instance of SimpleMenuItem
public auto createSimpleMenuItem(actionT)(string text, actionT action, bool enabled = true)
{
    return new SimpleMenuItem!actionT(text, action, enabled);
}

@("Test SimpleMenuItem can call functions with no arguments")
unittest
{
    bool f1WasCalled;
    void f1() 
    {
        f1WasCalled = true;
    }

    IMenuItem f1Caller = createSimpleMenuItem("f1Caller", &f1);

    f1Caller.execute();
    assert(f1WasCalled);

    bool lambdaWasCalled;
    IMenuItem lambdaCaller = createSimpleMenuItem("lambdaCaller", {lambdaWasCalled = true;});    

    lambdaCaller.execute();
    assert(lambdaWasCalled);
}

@("Test SimpleMenuItem can call methods with no arguments")
unittest
{
    struct TestStruct
    {
        bool methodWasCalled;
        void method()
        {
            methodWasCalled = true;
        }
    }

    TestStruct testStructInstance;
    IMenuItem structMethodCaller = createSimpleMenuItem("structMethodCaller", &testStructInstance.method);

    structMethodCaller.execute();
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
    IMenuItem classMethodCaller = createSimpleMenuItem("classMethodCaller", &testClassInstance.method);

    classMethodCaller.execute();
    assert(testClassInstance.methodWasCalled);
}
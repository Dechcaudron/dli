module dli.helper_functions;

import dli.exceptions.no_menu_running_exception;
import dli.menu;
import std.conv;
import std.meta;
import std.string;

/** 
    Helper method to require a string confirmation inside an action item.
    The user input is passed to std.string.strip before it is compared
    to the requiredConfirmationAnswer.

    Throws NoMenuRunningException if no menu is running.
*/
public bool requireConfirmation(string requestConfirmationMsg, string requiredConfirmationAnswer)
in
{
    assert(requestConfirmationMsg !is null);
    assert(requiredConfirmationAnswer !is null);
}
body
{
    import std.string : strip;

    enforce!NoMenuRunningException(activeTextMenu !is null,
                                   "requireConfirmation needs a running menu " ~
                                   "from which to ask for confirmation");
    
    activeTextMenu.write(requestConfirmationMsg);
    
    return activeTextMenu.readln().strip() == requiredConfirmationAnswer;
}

/**
    Helper method to require data with type and possible additional restrictions.
    The user input is passed to std.string.strip before conversion is attempted.
    
    Returns whether or not the input data is valid. If false, no writing has been
    performed into dataDestination.

    Throws NoMenuRunningException if no menu is running.
*/
public bool requestData(dataT, restrictionCheckerT)
            (string requestMsg,
            dataT* dataDestination,
            string onInvalidDataMsg = "Invalid data.",
            restrictionCheckerT restriction = (dataT foo){return true;}, // No restrictions by default
            )
in
{
    assert(requestMsg !is null);
    assert(dataDestination !is null);
    assert(onInvalidDataMsg !is null);
    assert(restriction !is null);
}
body
{
    enforce!NoMenuRunningException(activeTextMenu !is null,
                                   "requestData needs a running menu " ~
                                   "from which to ask for data. " ~
                                   "Are you calling it from outside a MenuItem?");

    try
    {
        string input = activeTextMenu.readln().strip();
        dataT data = to!dataT(input);
        if(restriction(data))
        {
            *dataDestination = data;
            return true;
        }
    }
    catch(ConvException e)
    {
    }

    activeTextMenu.writeln(onInvalidDataMsg);
    return false;
}

// TESTS
version(unittest)
{
    import std.exception;
    import test.dli.mock_menu;
    import test.dli.mock_menu_item;
    import unit_threaded;

    @("requireConfirmation works if called from within MenuItem")
    unittest
    {
        auto menu = new MockMenu();
        immutable string confirmationAnswer = "_CONFIRM_"; // Just a random string   

        class CustomMenuItem : MockMenuItem
        {
            protected override void execute()
            {
                if(requireConfirmation("", confirmationAnswer))
                    super.execute();
            }
        }

        auto item = new CustomMenuItem();

        menu.addItem(item, 1);

        menu.mock_writeln("1");
        menu.mock_writeln("asdf"); // Whatever different from confirmationAnswer
        menu.mock_writeExitRequest();
        menu.run();

        assert(!item.executed);

        menu.mock_writeln("1");
        menu.mock_writeln(confirmationAnswer);
        menu.mock_writeExitRequest();
        menu.run();

        assert(item.executed);
    }

    @("requireConfirmation throws NoMenuRunningException if called directly")
    unittest
    {
        assertThrown!NoMenuRunningException(requireConfirmation("",""));
    }

    class SimpleMenuItem : MockMenuItem
    {
        void delegate() action;

        this(typeof(action) action)
        in
        {
            assert(action !is null);
        }
        body
        {
            this.action = action;
        }

        protected override void execute()
        {
            action();
        }
    }

    static foreach (alias supportedType; AliasSeq!(
                        byte,
                        short,
                        int,
                        long,
                        float,
                        double,
                        char,
                        string
                    ))
    {
        @("requestData works for type " ~ supportedType.stringof)
        unittest
        {
        
            auto menu = new MockMenu();

            supportedType myData;
            bool dataValid;

            menu.addItem(
                new SimpleMenuItem(
                    {dataValid = requestData("", &myData);}
                ), 1
            );

            enum supportedTypeIsConvertible(T) = is(supportedType : T);

            // The user inputs a character
            enum charInput = "a";
            menu.mock_writeln("1");
            menu.mock_writeln(charInput);
            menu.mock_writeExitRequest();
            menu.run();

            enum charIsValidInput = is(supportedType == char) || 
                                    is(supportedType == string);

            assert(dataValid == charIsValidInput);
            static if (charIsValidInput)
                assert(myData == to!supportedType(charInput));

            // The user inputs a general string
            enum stringInput = "Yo I'm a string";
            menu.mock_writeln("1");
            menu.mock_writeln(stringInput);
            menu.mock_writeExitRequest();
            menu.run();

            enum stringIsValidInput = is(supportedType == string);

            assert(dataValid == stringIsValidInput);
            static if (stringIsValidInput)
                assert(myData == stringInput);

            // The user inputs a fractional number
            enum fractionalInput = "1.23";
            menu.mock_writeln("1");
            menu.mock_writeln(fractionalInput);
            menu.mock_writeExitRequest();
            menu.run();

            enum fractionalIsValidInput = is(supportedType == float) || 
                                          is(supportedType == double) || 
                                          is(supportedType == string);

            dataValid.shouldEqual(fractionalIsValidInput);
            static if (fractionalIsValidInput)
                myData.shouldEqual(to!supportedType(fractionalInput));

            // The user inputs a positive integer
            enum integerInput = "8";
            menu.mock_writeln("1");
            menu.mock_writeln(integerInput);
            menu.mock_writeExitRequest();
            menu.run();

            enum integerIsValidInput = is(supportedType : long) ||
                                       is(supportedType : ulong) ||
                                       is(supportedType == float) ||
                                       is(supportedType == double) ||
                                       is(supportedType == string);

            dataValid.shouldEqual(integerIsValidInput);
            static if (integerIsValidInput)
                myData.shouldEqual(to!supportedType(integerInput));

            // The user inputs a negative integer
            enum negativeIntegerInput = "-8";
            menu.mock_writeln("1");
            menu.mock_writeln(negativeIntegerInput);
            menu.mock_writeExitRequest();
            menu.run();

            enum negativeIntegerIsValidInput = !is(supportedType == char) &&
                                               is(supportedType : long) ||
                                               is(supportedType == float) ||
                                               is(supportedType == double) ||
                                               is(supportedType == string);

            dataValid.shouldEqual(negativeIntegerIsValidInput);
            static if (negativeIntegerIsValidInput)
                myData.shouldEqual(to!supportedType(negativeIntegerInput));
        }
    }
    

    @("requestData can take restrictions")
    unittest
    {
        auto menu = new MockMenu();
        //int myData == 6);
    }

    @("requestData throws NoMenuRunningException if called directly")
    unittest
    {
        int dummy;
        assertThrown!NoMenuRunningException(requestData("", &dummy, ""));
    }
}
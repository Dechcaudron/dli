module dli.helper_functions;

import dli.exceptions.no_menu_running_exception;
import dli.text_menu;
import std.conv;
import std.exception;
import std.meta;
import std.string : chomp;
import std.traits;

/** 
    Helper method to require a string confirmation inside an action item.

    Returns: whether or not the user input, stripped of line terminators,
             exactly matches requiredAnswer.

    Throws: NoMenuRunningException if no menu is running in the calling thread.
*/
public bool requestConfirmation(string requestMsg, string requiredAnswer)
in
{
    assert(requestMsg !is null);
    assert(requiredAnswer !is null);
}
body
{
    import std.string : strip;

    enforce!NoMenuRunningException(activeTextMenu !is null,
                                   "requestConfirmation needs a running menu " ~
                                   "from which to ask for confirmation");

    string answer;
    return request!string(requestMsg, &answer) &&
           answer == requiredAnswer;
}

/// Types supported by the helper 'request' method
private alias requestSupportedTypes = AliasSeq!(
    ubyte,
    ushort,
    uint,
    ulong,
    byte,
    short,
    int,
    long,
    char,
    // wchar, not supported until to!(wchar, string) is available in Phobos
    dchar,
    float,
    double,
    real,
    string,
    wstring,
    dstring
);

/**
    Helper method to require data with type and possible additional restrictions.

    The user input is stripped of the line terminator before conversion is attempted.

    Params: requestMsg      = message to write out when asking for data.
            dataDestination = pointer where the data should be stored,
                              if the input is valid.
            restriction     = a callable item that takes a single dataT argument
                              and returns whether it is valid or not. Use it to
                              add additional restrictions onto the data being
                              requested.

    
    Returns: whether or not the input data is valid. If false, no writing has been
    performed into dataDestination.

    Throws: NoMenuRunningException if no menu is running in the calling thread.
*/
public bool request(dataT, restrictionCheckerT)
            (string requestMsg,
            dataT* dataDestination,
            restrictionCheckerT restriction = (dataT foo){return true;}, // No restrictions by default
            )
if(staticIndexOf!(dataT, requestSupportedTypes) != -1 &&
   isCallable!restrictionCheckerT &&
   Parameters!restrictionCheckerT.length == 1 &&
   is(Parameters!restrictionCheckerT[0] : dataT) &&
   is(ReturnType!restrictionCheckerT == bool))
in
{
    assert(requestMsg !is null);
    assert(dataDestination !is null);
    assert(restriction !is null);
}
body
{
    enforce!NoMenuRunningException(activeTextMenu !is null,
                                   "'request' needs a running menu " ~
                                   "from which to ask for data. " ~
                                   "Are you calling it from outside a MenuItem?");

    write(requestMsg);
    try
    {
        string input = activeTextMenu.readln().chomp();
        dataT data = to!dataT(input);
        if(restriction(data))
        {
            *dataDestination = data;
            return true;
        }
    }
    catch(Exception e)
    {
    }

    return false;
}

/**
    Helper method to write to the output string of the currently running menu.

    Params: s = string to write.

    Throws: NoMenuRunningException if no menu is running in the calling thread.
*/
public void write(string s)
in
{
    assert(s !is null);
}
body
{
    enforce!NoMenuRunningException(activeTextMenu !is null,
                                   "'write' needs a running menu " ~
                                   "from which to write");
    activeTextMenu.write(s);
}

/**
    Helper method to write to the output string of the currently running menu,
    plus an end-of-line sequence.

    Params: s = string to write.

    Throws: NoMenuRunningException if no menu is running in the calling thread.
*/
public void writeln(string s)
in
{
    assert(s !is null);
}
body
{
    enforce!NoMenuRunningException(activeTextMenu ! is null,
                                   "'writeln' requires a running menu " ~
                                   "from which to write a line");
    activeTextMenu.writeln(s);
}

// TESTS
version(unittest)
{
    import std.exception;
    import test.dli.mock_menu;
    import test.dli.mock_menu_item;
    import unit_threaded;

    @("requestConfirmation works if called from within MenuItem")
    unittest
    {
        auto menu = new MockMenu();
        immutable string confirmationAnswer = "_CONFIRM_"; // Just a random string   
        bool confirmed;

        auto item = new MenuItem("",
            {
                confirmed = requestConfirmation("", confirmationAnswer);
            }
        );

        menu.addItem(item, 1);

        menu.mock_writeln("1");
        menu.mock_writeln("asdf"); // Whatever different from confirmationAnswer
        menu.mock_writeExitRequest();
        menu.run();

        assert(!confirmed);

        menu.mock_writeln("1");
        menu.mock_writeln(confirmationAnswer);
        menu.mock_writeExitRequest();
        menu.run();

        assert(confirmed);
    }

    @("requestConfirmation throws NoMenuRunningException if called directly")
    unittest
    {
        assertThrown!NoMenuRunningException(requestConfirmation("",""));
    }

    static foreach (alias supportedType; requestSupportedTypes)
    {
        @("request works for type " ~ supportedType.stringof)
        unittest
        {
            auto menu = new MockMenu();

            supportedType myData;
            bool dataValid;

            menu.addItem(
                new MenuItem("",
                             {dataValid = request("", &myData);}
                            ),
                1
            );

            enum supportedTypeIsConvertible(T) = is(supportedType : T);

            // The user inputs an ASCII character
            enum charInput = "a";
            menu.mock_writeln("1");
            menu.mock_writeln(charInput);
            menu.mock_writeExitRequest();
            menu.run();

            enum charIsValidInput = isSomeChar!supportedType ||
                                    isSomeString!supportedType;

            assert(dataValid == charIsValidInput);
            static if (charIsValidInput)
                assert(myData == to!supportedType(charInput));

            // The user inputs a double-byte Unicode character
            enum wcharInput = "á";
            menu.mock_writeln("1");
            menu.mock_writeln(wcharInput);
            menu.mock_writeExitRequest();
            menu.run();

            enum wcharIsValidInput = is(supportedType == wchar) ||
                                     is(supportedType == dchar) ||
                                     isSomeString!supportedType;

            assert(dataValid == wcharIsValidInput);
            static if (wcharIsValidInput)
                assert(myData == to!supportedType(wcharInput));

            // The user inputs a quadruple-byte Unicode character
            enum dcharInput = "🙂";
            menu.mock_writeln("1");
            menu.mock_writeln(dcharInput);
            menu.mock_writeExitRequest();
            menu.run();

            enum dcharIsValidInput = is(supportedType == dchar) ||
                                     isSomeString!supportedType;

            assert(dataValid == dcharIsValidInput);
            static if (dcharIsValidInput)
                assert(myData == to!supportedType(dcharInput));

            // The user inputs a general string
            enum stringInput = "This is English. Esto es español. 這是中國人.";
            menu.mock_writeln("1");
            menu.mock_writeln(stringInput);
            menu.mock_writeExitRequest();
            menu.run();

            enum stringIsValidInput = isSomeString!supportedType;

            assert(dataValid == stringIsValidInput);
            static if (stringIsValidInput)
                assert(myData == stringInput);

            // The user inputs a fractional number
            enum fractionalInput = "1.23";
            menu.mock_writeln("1");
            menu.mock_writeln(fractionalInput);
            menu.mock_writeExitRequest();
            menu.run();

            enum fractionalIsValidInput = isFloatingPoint!supportedType || 
                                          isSomeString!supportedType;

            dataValid.shouldEqual(fractionalIsValidInput);
            static if (fractionalIsValidInput)
                myData.shouldEqual(to!supportedType(fractionalInput));

            // The user inputs a positive integer
            enum integerInput = "15";
            menu.mock_writeln("1");
            menu.mock_writeln(integerInput);
            menu.mock_writeExitRequest();
            menu.run();

            enum positiveIntegerIsValidInput = isNumeric!supportedType ||
                                               isSomeString!supportedType;

            dataValid.shouldEqual(positiveIntegerIsValidInput);
            static if (positiveIntegerIsValidInput)
                myData.shouldEqual(to!supportedType(integerInput));

            // The user inputs a negative integer
            enum negativeIntegerInput = "-8";
            menu.mock_writeln("1");
            menu.mock_writeln(negativeIntegerInput);
            menu.mock_writeExitRequest();
            menu.run();

            enum negativeIntegerIsValidInput = isSigned!supportedType ||
                                               isSomeString!supportedType;

            dataValid.shouldEqual(negativeIntegerIsValidInput);
            static if (negativeIntegerIsValidInput)
                myData.shouldEqual(to!supportedType(negativeIntegerInput));
        }
    }
    
    @("request!char accepts whitespace")
    unittest
    {
        auto menu = new MockMenu();
        bool dataValid;
        char inputChar;
        auto item = new MenuItem("",
            {
                dataValid = request!char("", &inputChar);
            }
        );

        menu.addItem(item, 1);
        menu.mock_writeln("1");
        menu.mock_writeln(" ");
        menu.mock_writeExitRequest();
        menu.run();

        assert(dataValid);
        assert(inputChar == ' ');
    }

    @("request can take restrictions")
    unittest
    {
        int myInt;
        bool dataValid;
        auto menu = new MockMenu();

        menu.addItem(
            new MenuItem("",
                         {
                             dataValid = request!int("", &myInt, (int a){return a % 2 == 0;}); // Only accepts even integers
                         }
                        ),
            1
        );

        menu.mock_writeln("1");
        menu.mock_writeln("5"); // Not an even integer
        menu.mock_writeExitRequest();
        menu.run();

        assert(!dataValid);

        menu.mock_writeln("1");
        menu.mock_writeln("8"); // Even integer
        menu.mock_writeExitRequest();
        menu.run();

        assert(dataValid);
        assert(myInt == 8);
    }

    @("request throws NoMenuRunningException if called directly")
    unittest
    {
        int dummy;
        assertThrown!NoMenuRunningException(request("", &dummy));
    }
}
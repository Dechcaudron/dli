/**
    Implements QoL functions to handle user input-output.

    Unless otherwise stated, all methods make use of `stdin` and
    `stdout` for input and output, respectively, or this thread's
    running `ITextMenu`, if any.
*/
module dli.io;

import dli.text_menu;
import std.conv;
import std.exception;
import std.meta;
import std.stdio : stdin, stdout;
import std.string : chomp, format;
import std.traits;

/** 
    Requests a text confirmation from the user.

    Returns: whether or not the user input, stripped of line terminators,
             exactly matches requiredAnswer.
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

    string answer;
    return request!string(requestMsg, &answer, (string s){return s == requiredAnswer;});
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
    Requests data with the possibility of adding restrictions.
    User input is stripped of the line terminator before processing is attempted.

    Params: requestMsg      = message to write out when asking for data.
            dataDestination = pointer where the input data is to be stored,
                              if the input can be converted and satifsties 
                              restriction.
            restriction     = a callable item that takes a single dataT argument
                              and returns whether it is valid or not. Use it to
                              add additional restrictions onto the data being
                              requested.
    
    Returns: whether or not the input data is valid. If `false`, no writing has been
    performed into dataDestination.
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
    string input;
    if(activeTextMenu is null)
    {
        stdout.write(requestMsg);
        input = stdin.readln().chomp();
    }
    else
    {
        activeTextMenu.write(requestMsg);
        input = activeTextMenu.readln().chomp();
    }

    if (input is null)
        return false;

    version(MathExpressionSupport)
        enum supportMathExpr = true;
    else
        enum supportMathExpr = false;

    try
    {
        dataT data = void;
        static if (supportMathExpr && isNumeric!dataT)
        {
            import arith_eval : Evaluable;

            auto evaluable = Evaluable!()(input);
            static if (isFloatingPoint!dataT)
                data = evaluable.eval();
            else
            {
                import std.math : abs, round;

                immutable float floatResult = evaluable.eval();
                immutable float closestInteger = round(floatResult);
                enum validThreshold = 0.01f;
                if (abs(floatResult - closestInteger) <= validThreshold)
                    data = to!dataT(evaluable.eval());
                else
                    throw new Exception(
                        format("Evaluated input \"%s\" is too far from nearest integer %s " ~
                               "to be considered a valid integer input.")
                    );
            }
        }
        else
            data = to!dataT(input);
        
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
    Writes s to the output.

    Params: s = string to write.
*/
public void write(string s)
in
{
    assert(s !is null);
}
body
{
    if(activeTextMenu is null)
        stdout.write(s);
    else
        activeTextMenu.write(s);
}

/**
    Writes s, plus a line terminator, to the output.

    Params: s = string to write.
*/
public void writeln(string s)
in
{
    assert(s !is null);
}
body
{
    if(activeTextMenu is null)
        stdout.writeln(s);
    else
        activeTextMenu.writeln(s);
}

// TESTS
version(unittest)
{
    import std.exception;
    import test.dli.mock_menu;
    import test.dli.mock_menu_item;
    import unit_threaded;

    version = MathExpressionSupport;

    @("requestConfirmation works if called from a running ITextMenu")
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
        menu.mock_writeln(confirmationAnswer ~ "a"); // Contains confirmation answer, but does not match
        menu.mock_writeExitRequest();
        menu.run();

        assert(!confirmed);

        menu.mock_writeln("1");
        menu.mock_writeln(confirmationAnswer);
        menu.mock_writeExitRequest();
        menu.run();

        assert(confirmed);
    }

    enum isValidInput(string input) = false;
    enum isValidInput(string input : "a") = true;

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

            //enum isValidInput(string input) = false;
            //enum isValidInput(string input : "a") = true;

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
            {
                static if (isSomeString!supportedType)
                    myData.shouldEqual(to!supportedType(fractionalInput));
                else static if (isFloatingPoint!supportedType)
                    myData.shouldApproxEqual(to!supportedType(fractionalInput));
            }

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

            
            // The user inputs an integer-yielding math expression
            enum integerYieldingMathExp = "4 / 2";
            menu.mock_writeln("1");
            menu.mock_writeln(integerYieldingMathExp);
            menu.mock_writeExitRequest();
            menu.run();

            enum integerYieldingMathExpIsValidInput =
                isSomeString!supportedType ||
                isNumeric!supportedType;
            
            dataValid.shouldEqual(integerYieldingMathExpIsValidInput);
            static if (integerYieldingMathExpIsValidInput)
            {
                static if (isSomeString!supportedType)
                    myData.shouldEqual(to!supportedType(integerYieldingMathExp));
                else
                    myData.shouldEqual(to!supportedType("2")); // 4 / 2 = 2;
            }

            // The user inputs an integer-yielding math expression
            enum floatYieldingMathExp = "1 / 3";
            menu.mock_writeln("1");
            menu.mock_writeln(floatYieldingMathExp);
            menu.mock_writeExitRequest();
            menu.run();

            enum floatYieldingMathExpIsValidInput =
                isSomeString!supportedType ||
                isFloatingPoint!supportedType;
            
            dataValid.shouldEqual(floatYieldingMathExpIsValidInput);
            static if (floatYieldingMathExpIsValidInput)
            {
                static if (isSomeString!supportedType)
                    myData.shouldEqual(to!supportedType(floatYieldingMathExp));
                else
                    myData.shouldApproxEqual(to!supportedType(1f / 3));
            }
                
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

    @("request supports math expressions")
    unittest
    {
        int userInput;
        bool dataValid;
        auto menu = new MockMenu();

        menu.addItem(
            new MenuItem("",
                {
                    dataValid = request("", &userInput, (int a){return a % 2 == 0;});
                }
            ), 1
        );

        menu.mock_writeln("1");
        menu.mock_writeln("asdf");
        menu.mock_writeExitRequest();
        menu.run();

        assert(!dataValid);

        menu.mock_writeln("1");
        menu.mock_writeln("1 + 2"); // Not valid, odd value
        menu.mock_writeExitRequest();
        menu.run();

        assert(!dataValid);

        menu.mock_writeln("1");
        menu.mock_writeln("2 + 2");
        menu.mock_writeExitRequest();
        menu.run();

        assert(dataValid);
        assert(userInput == 4);
    }
}
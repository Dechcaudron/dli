module dli.exceptions.no_menu_running_exception;

import std.exception;

public class NoMenuRunningException : Exception
{
    mixin basicExceptionCtors;
}
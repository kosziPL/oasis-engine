package;

import haxe.CallStack;
import haxe.PosInfos;

/** Diagnostics for missing objects; does not suppress the original failure. */
class NullDiagnostics
{
	/** Check each parent separately before accessing a chain such as sprite.animation.curAnim. */
	public static function requireNotNull<T>(value:T, name:String, ?context:String, ?pos:PosInfos):T
	{
		if (value != null)
			return value;

		var message = 'Null Object Reference: "' + name + '" is null.';
		if (pos != null)
			message += '\nLocation: ' + pos.fileName + ':' + pos.lineNumber + ' (' + pos.className + '.' + pos.methodName + ')';
		if (context != null && context != "")
			message += '\nContext: ' + context;
		message += '\nThe object must exist before accessing its fields or methods.';
		throw new haxe.Exception(message);
	}

	/** The stack identifies the failing access, but cannot reveal local variable values. */
	public static function describe(error:Dynamic, stack:Array<haxe.CallStack.StackItem>):String
	{
		var message = Std.string(error);
		var normalized = message.toLowerCase();
		if (normalized.indexOf("null object reference") == -1 && normalized.indexOf("null access") == -1)
			return "";

		var report = '\nNull reference diagnostics:\n'
			+ 'A field or method was accessed on an object whose value is null.\n'
			+ 'Possible causes (not confirmed): initialization was skipped, a lookup or asset load returned null, '
			+ 'or the reference was cleared during cleanup.\n'
			+ 'Check the failing source line and each object in the access chain. '
			+ 'Use NullDiagnostics.requireNotNull(value, "variable name", "operation") before the access '
			+ 'to identify the missing object.\n';
		if (stack != null && stack.length > 0)
			report += 'Exception stack:' + CallStack.toString(stack) + '\n';
		else
			report += 'No exception stack available; reproduce with a debug build for source locations.\n';
		return report;
	}
}

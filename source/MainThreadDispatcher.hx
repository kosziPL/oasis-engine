package;

#if sys
import sys.thread.Deque;
#end


class MainThreadDispatcher
{
	#if sys
	static var queue:Deque<Void->Void> = new Deque();
	#end

	public static function runOnMain(fn:Void->Void):Void
	{
		#if sys
		queue.add(fn);
		#else
		fn();
		#end
	}

	public static function pump(maxPerFrame:Int = 16):Void
	{
		#if sys
		var n = 0;
		while (n < maxPerFrame)
		{
			var fn = queue.pop(false); // non-blocking
			if (fn == null)
				break;
			try
				fn()
			catch (e:Dynamic)
				trace('MainThreadDispatcher: błąd zadania - $e');
			n++;
		}
		#end
	}
}

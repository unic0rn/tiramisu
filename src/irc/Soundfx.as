package irc
{
	import flash.media.Sound;
	import flash.media.SoundChannel;
	import flash.media.SoundTransform;
	
	public class Soundfx
	{
		[Embed(source='notification1.mp3')]
		internal static var n1:Class;
		[Embed(source='notification2.mp3')]
		internal static var n2:Class;
		internal static var n1fx:Sound = new n1();
		internal static var n2fx:Sound = new n2();
		internal static var sc:SoundChannel;
                internal static var current:int = 1;
                public static var mute:Boolean = false;
		
		public static function play():void
		{
                    if (!mute) {
                        if (current == 1) {
                            sc = n1fx.play();
                            sc.soundTransform = new SoundTransform(1, 0);
                            current = 2;
                        } else {
                            sc = n2fx.play();
                            sc.soundTransform = new SoundTransform(1, 0);
                            current = 1;
                        }
                    }
		}
	}
}

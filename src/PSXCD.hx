/********************************************************************
 * READ A PSX CD AND GET METADATA
 *  
 * - Supports reading .BIN files
 * - With the help of `pismomount` can read .BIN files from within .ZIP .CFO .PFO archives
 * 
 *******************************************************************/


package ;
import djNode.BaseApp;
import djNode.app.PismoMount;
import djNode.tools.FileTool;
import js.Node;
import js.html.LabelElement;
import js.lib.Error;
import js.node.Buffer;
import js.node.Fs;
import js.node.Path;


typedef PSXCDINFO = {
	label:String,		// 0x9340 , 32 len
	publisher:String,	// 0x9456 , 128 len
	date:String			// 0x9645 , 8 len | Date is in YYYYMMDD format
};


class PSXCD
{
	
	// In case of operation error, this stores the error message
	public static var ERROR:String;
	
	
	/** 
	   Get data from a supported file
	   @param	path Supports (zip/cfs/pfo/bin) -- Needs PismoMount to mount the files
	   @param	callback Null for error
	**/
	public static function parseMulti(path:String, callback:PSXCDINFO->Void)
	{
		trace(">>> Getting CD INFOS for " + path);
		
		function qErr(s:String):Void
		{
			ERROR = s;
			trace("ERROR : " + s);
			callback(null);
		}
		
		var ext = Path.extname(path).toLowerCase();
		
		//var FILENAME:String = Path.basename(path);
		var BINFILE:String = null;
		var mounted:Bool = false;
		
		// -- Ready the bin file 
		
		if (['.zip', '.cfs', '.pfo'].indexOf(ext) >= 0)
		{
			// it is an archive
			var newp = PismoMount.mount(path);
			if (newp == null) 
				return qErr('Cannot mount archive');

			mounted = true;
			
			var files = FileTool.getFiles(newp, false, ['.bin']);
			if (files.length == 0) {
				PismoMount.unmount(path);
				return qErr('Did not find any BIN files in archive');
			}
			
			BINFILE = files[0];
			
		}else if ( ext == ".bin") {
			BINFILE = path;
		}else{
			return qErr('Unsupported extension "$ext"');
		}
		
		// -- Bin file is ready. Get data.
		
		parseBin(BINFILE, (data)->{
			
			if (mounted) PismoMount.unmount(path);
			
			if (data == null) 
				return qErr('Cannot read .BIN file');
			
			callback(data);
			
		});
		
	}//---------------------------------------------------;
	
	
	/**
	   Get metadata from .BIN file
	   @param	file a BIN file, IT MUST EXIST!!
	   @param	callback NULL for error
	**/
	public static function parseBin(file:String, callback:PSXCDINFO->Void)
	{
		Fs.open(file, FsOpenFlag.Read, function(er:Error, fd:Int) {
			
			function read(start:Int, len:Int):String
			{
				var b = Buffer.alloc(len);
				Fs.readSync(fd, b, 0, len, start);
				return b.toString();
			}
			
			if (er != null) {
				callback(null);
				return;
			}
			
			var date0 = read(0x9645, 8);
			
			var o:PSXCDINFO = {
				label: 		StringTools.rtrim(read(0x9340, 32)),
				publisher:	StringTools.rtrim(read(0x9456, 128)),
				date:		date0.substr(0, 4) + '-' + date0.substr(4, 2) + '-' + date0.substr(-2)
			};
			
			Fs.closeSync(fd);
			callback(o);
		});
		
	}//---------------------------------------------------;
	
}//-
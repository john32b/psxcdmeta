package;

import djA.ArrayExecSync;
import djA.StrT;
import djNode.BaseApp;
import djNode.tools.FileTool;
import djNode.tools.LOG;
import djNode.utils.CLIApp;
import djNode.utils.Print2;
import js.Node;
import js.node.Fs;

class Main extends BaseApp
{
	static function main() new Main();
	
	static var EXT_0 = [ '.bin' ];
	static var EXT_1 = [ '.zip', '.pfo', '.cfs' ];
	
	override function init():Void 
	{
		LOG.pipeTrace(); // All traces will redirect to LOG object
		
		#if debug
		//js.Lib.require('source-map-support').install();
		LOG.setLogFile("a:\\PSX_CD_META.txt");
		#end
		
		PROGRAM_INFO = {
			name:"PSX CD Metadata",
			desc:"Get Playstation 1 Disc Metadatas",
			version:"0.1"
		};
		
		ARGS.outputRule = 'opt';
		ARGS.helpOutput = 'Will produce a file e.g. -o result.txt';
		
		ARGS.inputRule = 'yes';
		ARGS.helpInput = 'File or Folder.';
		
		ARGS.Options = [
			['d', 'If input is a folder, deepscan it for files'],
			['zip', 'Will also process .ZIP files. <yellow>! Requires Pismo Mount to be installed !<!>']
		];
		
		ARGS.helpText = 
			' <magenta>Example<!>\n' + 
			'     - Get infos from all .zip and .bin games and create a text file :: \n' + 
			'       node app c:\\roms\\ps1 -d -zip -o c:\\roms\\ps1report.txt';
				
		super.init();
	}//---------------------------------------------------;
	
	
	// This is the user code entry point :
	// --
	override function onStart() 
	{
		var P = new Print2(1);
		var input = argsInput[0];
		var OUT:Array<String> = [];	// This is the output file text
		
		if (!Fs.existsSync(input))
		{
			exitError('Input:"$input" does not exist');
		}
		
		var isDir = Fs.statSync(argsInput[0]).isDirectory();
		var deepScan = argsOptions.d;
		var usepismo = argsOptions.zip;
		var EXTENSIONS = EXT_0.copy();	// Extensions to scan
		
		
		if (usepismo)
		{
			if (!CLIApp.checkRun('pfm.exe'))
			{
				exitError('PISMO MOUNT is not installed OR <yellow>"pfm.exe"<!> is not on path.');
			}
		
			EXTENSIONS = EXTENSIONS.concat(EXT_1);
		}
		
		P.br().H('PSX METADATA');
		P.ptem("Input  : <yellow>{1}<!>" + (isDir?(deepScan?" <darkgray>(deepscan)<!>":""):""), argsInput[0]);
		
		if (argsOutput != null)
		{
			P.ptem("Output : <cyan>{1}<!>", argsOutput);
			
			if (Fs.existsSync(argsOutput))
			{
				exitError('Output:"$argsOutput" already exists');
			}
			
			OUT = P.buffer.copy(); // -- Copy what was printed this far
			OUT.push(StrT.rep(40,'-'));
		}
		
		// -- Gather the files ---------------
		
		var FILES:Array<String> = [];
		
		if (isDir)
		{
			FILES = FileTool.getFiles(input, deepScan, EXTENSIONS);
			if (FILES.length == 0) {
				P.p('>> <yellow>Directory returned 0 files<!>');
				Sys.exit(1);
			}
		}else{
			
			if (EXTENSIONS.indexOf(FileTool.getFileExt(input)) < 0)
			{
				P.p('>> <yellow>File not valid extension<!>');
				Sys.exit(1);
			}
			
			FILES.push(input);
		}
		
		// -- Process the files ---------------
		
		var ax = new ArrayExecSync(FILES);
		
		ax.onItem = (file)->{
			
			var fileno = '(${ax.C+1}/${FILES.length})';
			P.ptem(">> <yellow>{1}<!> File : <cyan>{2}<!> ", fileno, file);
			
			PSXCD.parseMulti(file, (data)->{
				
				if (data == null) 
				{
					P.ptem('   <red>ERROR<!> {1}', PSXCD.ERROR);
					OUT.push(file + "|" +'ERROR : ' + PSXCD.ERROR);
					ax.next();
					
				}else{
					
					P.ptem('   CD Date : <green>{1}<!> Label : {2}', data.date, data.label);
					
					OUT.push(
						js.node.Path.relative(input, file) + "|" +
						data.date + "|" + 
						data.label + "|" +
						data.publisher
						);
						
					Node.setTimeout(ax.next, 1);	// Escape the callstack
				}
			});
		}
		

		function writeOut()
		{
			if (argsOutput != null) // Write the output file
			{
				P.ptem('Writing data to file <yellow>"{1}"<!>', argsOutput);
				
				try{
					Fs.writeFileSync(argsOutput, OUT.join('\n'));
					P.p('<green>[OK]<!>');
				}catch (_) {
					P.p('<red>ERROR<!> Could not write file? Do you have write access? Free space?');
				}
			}
		}// - yes a function inside another function -
		
		
		ax.onComplete = ()->
		{
			P.line().H("ALL DONE").br();
			writeOut();
		}
		
		// In case the program crashes, still call writeout and then exit
		onExit_ = (c)->
		{
			if (c > 0) 
			{
				P.p('<yellow> Early Exit. <!>');
				writeOut();
			}
		}
		
		P.line();
		ax.start();
	}//---------------------------------------------------;	

}// --
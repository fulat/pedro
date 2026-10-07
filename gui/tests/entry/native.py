#!/usr/bin/env python3
"""GNOME/Wayland pointer regression using real Pedro Files and generated fixtures.
Requires PyGObject, GStreamer/PipeWire and the Pedro GNOME extension. The default
pointer coordinates are calibrated for the development display (1728x1084, 2x).
Set DRAG_SOURCE_POINT and DRAG_TARGET_POINT for a different window placement.
DRAG_COLUMNS=1 tests column destinations; DRAG_FROM_CHILD=1 moves back to the parent.
DRAG_EMPTY_FOLDER=1 drags an empty folder instead of a text file.
Only the diagnostic process is terminated; the user's Pedro process stays open.
"""
import os, json, signal, subprocess, time, queue, threading, shutil
from pathlib import Path
import gi
gi.require_version('Gst','1.0')
from gi.repository import Gio, GLib, Gst
Gst.init(None)
root=Path(__file__).resolve().parents[3]; target=root/'build/verification/drag/native'
target.mkdir(parents=True,exist_ok=True)
for name in ('qml','config','assets'):
 link=target/name
 if not link.exists():link.symlink_to(root/'gui'/name,target_is_directory=True)
shutil.rmtree(target/'source',ignore_errors=True)
for name in ('source','desktop'):(target/name).mkdir(exist_ok=True)
supportName=os.environ.get('DRAG_DESTINATION_NAME','Support')
(target/'source'/supportName).mkdir(exist_ok=True)
columnMode=os.environ.get('DRAG_COLUMNS') == '1'
fromChild=columnMode and os.environ.get('DRAG_FROM_CHILD') == '1'
emptyFolder=os.environ.get('DRAG_EMPTY_FOLDER') == '1'
entryName='Native empty folder' if emptyFolder else 'Native text.txt'
sourceEntry=target/('source/'+supportName if fromChild else 'source')/entryName
if emptyFolder:sourceEntry.mkdir()
else:sourceEntry.write_text('Native drag regression fixture\n')
(target/'desktop'/entryName).unlink(missing_ok=True)
original=(root/'gui/Main.qml').read_text()
fixture=r'''
    property var dragProbeLoader: null
    property bool dragColumnHighlighted: false
    property string dragHighlightState: ""
    Timer {
        interval: 30; running: true; repeat: true
        onTriggered: {
            if (!main.dragProbeLoader) return;
            const panel = main.dragProbeFind(main.dragProbeLoader.item.contentItem, "filesColumns");
            if (!panel) return;
            const highlighted = [];
            for (let index = 0; index < panel.locations.length; ++index) {
                const column = main.dragProbeFind(panel, "filesDirectoryColumn-" + index);
                if (column && column.dropHighlighted) {
                    highlighted.push(index);
                    const row = main.dragProbeFind(column, "filesColumn-" + index + "-@DESTINATION_NAME@");
                    if (row && row.dropTarget) console.log("FOLDER_DROP_FILL " + row.color);
                    if (!main.dragColumnHighlighted) console.log("COLUMN_DROP_HIGHLIGHT " + index);
                    main.dragColumnHighlighted = true;
                }
            }
            const state = JSON.stringify(highlighted);
            if (main.dragHighlightState !== state) {
                main.dragHighlightState = state;
                console.log("COLUMN_DROP_STATE " + state);
            }
        }
    }
    function dragProbeFind(item, name) {
        if (!item) return null;
        if (item.objectName === name) return item;
        for (const child of item.children || []) {
            const result = dragProbeFind(child, name);
            if (result) return result;
        }
        return null;
    }
    Timer {
        interval: 1200; running: true
        onTriggered: {
            main.title = "Pedro native drag diagnostic";
            main.x = 0; main.y = 32;
            const receiver = main.dragProbeFind(main.contentItem, "desktopDropDestination");
            receiver.location = "@DESKTOP@";
            main.dragProbeLoader = main.openFolderWindow("@SOURCE@");
            main.dragProbeLoader.item.x = 100; main.dragProbeLoader.item.y = 120;
            main.dragProbeLoader.item.width = 650; main.dragProbeLoader.item.height = 480;
            coordinates.start();
        }
    }
    Timer {
        id: coordinates; interval: 500; repeat: true
        onTriggered: {
            const window = main.dragProbeLoader.item;
            const entry = main.dragProbeFind(window.contentItem, "entryComponent-@ENTRY@");
            if (!entry || window.controller.directory.loading) return;
            Backend.activateWindow(window);
            const p = entry.inputSurface.mapToGlobal(entry.inputSurface.width / 2, 24);
            const d = main.contentItem.mapToGlobal(900, 550);
            const local = entry.inputSurface.mapToItem(window.contentItem, entry.inputSurface.width / 2, 24);
            Qt.callLater(() => console.log("DRAG_COORDINATES " + JSON.stringify({source: [p.x,p.y], local: [local.x,local.y], target: [d.x,d.y], ratio: main.Screen.devicePixelRatio, title: window.title, window: [window.x,window.y,window.width,window.height], screen: [main.Screen.width,main.Screen.height]})));
            stop();
        }
    }
'''

if columnMode:
 fixture=fixture.replace('main.dragProbeLoader.item.width = 650;', 'main.dragProbeLoader.item.controller.viewMode = "columns"; main.dragProbeLoader.item.width = 850;')
 fixture=fixture.replace('const entry = main.dragProbeFind(window.contentItem, "entryComponent-@ENTRY@");', '''const panel = main.dragProbeFind(window.contentItem, "filesColumns");
            if (!panel || panel.locations.length < 2) {
                if (panel) panel.updateLocations(["@SOURCE@", "@SOURCE@/@DESTINATION_NAME@"]);
                return;
            }
            const entry = main.dragProbeFind(panel, "entryComponent-@ENTRY@");''')
fixture=fixture.replace('@DESTINATION_NAME@',supportName)
fixture=fixture.replace('@SOURCE@',(target/'source').as_uri()).replace('@DESKTOP@',(target/'desktop').as_uri()).replace('@ENTRY@',entryName)
position=original.rfind('}')
(target/'Main.qml').write_text(original[:position]+fixture+original[position:])
bus=Gio.bus_get_sync(Gio.BusType.SESSION,None); ctx=GLib.MainContext.default()
r='org.gnome.Mutter.RemoteDesktop'; s='org.gnome.Mutter.ScreenCast'
def call(dest,path,method,args=None):
 return bus.call_sync(dest,path,*method.rsplit('.',1),args,None,Gio.DBusCallFlags.NONE,5000,None)
def wait(seconds):
 end=time.monotonic()+seconds
 while time.monotonic()<end:
  while ctx.pending():ctx.iteration(False)
  time.sleep(.01)
p=call(r,'/org/gnome/Mutter/RemoteDesktop',r+'.CreateSession').unpack()[0]
id=call(r,p,'org.freedesktop.DBus.Properties.Get',GLib.Variant('(ss)',(r+'.Session','SessionId'))).unpack()[0]
c=call(s,'/org/gnome/Mutter/ScreenCast',s+'.CreateSession',GLib.Variant('(a{sv})',({'remote-desktop-session-id':GLib.Variant('s',id)},))).unpack()[0]
st=call(s,c,s+'.Session.RecordMonitor',GLib.Variant('(sa{sv})',('',{'cursor-mode':GLib.Variant('u',2)}))).unpack()[0]
node=[]
bus.signal_subscribe(s,s+'.Stream','PipeWireStreamAdded',st,None,Gio.DBusSignalFlags.NONE,lambda *args:node.append(args[-1].unpack()[0]))
process=None; pipeline=None; started=False; pressed=False
try:
 call(r,p,r+'.Session.Start');started=True
 for i in range(100):
  wait(.05)
  if node:break
 print('STREAM',call(s,st,'org.freedesktop.DBus.Properties.Get',GLib.Variant('(ss)',(s+'.Stream','Parameters'))).unpack(), 'NODE',node,flush=True)
 pipeline=Gst.parse_launch(f'pipewiresrc path={node[0]} ! queue leaky=downstream max-size-buffers=1 max-size-bytes=0 max-size-time=0 ! videoconvert ! videoscale ! videorate ! video/x-raw,width=1728,height=1084,framerate=5/1 ! pngenc compression-level=1 ! appsink name=frames max-buffers=1 drop=true sync=false')
 pipeline.set_state(Gst.State.PLAYING); frames=pipeline.get_by_name('frames')
 def capture(name):
  while frames.emit('try-pull-sample',0):pass
  sample=frames.emit('try-pull-sample',2000000000)
  if sample:
   buffer=sample.get_buffer();(target/name).write_bytes(buffer.extract_dup(0,buffer.get_size()));print('CAPTURE',name,flush=True)
  else:print('CAPTURE FAILED',name,flush=True)
 env=dict(os.environ,WAYLAND_DEBUG='client',QT_QPA_PLATFORM='wayland',PEDRO_QML_DIR=str(target),PEDRO_DEVELOPMENT_MODE='1',PEDRO_DRAG_DIAGNOSTICS='1',PEDRO_DRAG_CAPTURE_PATH=str(target/'pixmap.png'))
 log=(target/'app.log').open('w')
 process=subprocess.Popen([str(root/'build/dev/gui/pedro-gui')],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,start_new_session=True,bufsize=1)
 lines=queue.Queue()
 def reader():
  for line in process.stdout:
   log.write(line);log.flush();lines.put(line)
 threading.Thread(target=reader,daemon=True).start()
 coords=None; until=time.monotonic()+25
 while time.monotonic()<until and not coords:
  try:
   line=lines.get(timeout=.1)
   if 'DRAG_COORDINATES ' in line:coords=json.loads(line.split('DRAG_COORDINATES ',1)[1])
  except queue.Empty:pass
  wait(.01)
 if not coords:raise RuntimeError('No native coordinates')
 print('ACTIVATE', call('org.pedro.Applications','/org/pedro/Applications','org.pedro.Applications.ActivateWindow',GLib.Variant('(us)',(process.pid,coords['title']))).unpack(), flush=True)
 wait(1)
 print('COORDS',coords,flush=True)
 def move(x,y):call(r,p,r+'.Session.NotifyPointerMotionAbsolute',GLib.Variant('(sdd)',(st,float(x),float(y))))
 scale=float(os.environ.get('DRAG_COORDINATE_SCALE',coords['ratio']))
 source=[float(v) for v in os.environ.get('DRAG_SOURCE_POINT','809,590').split(',')]; destination=[float(v) for v in os.environ.get('DRAG_TARGET_POINT','1320,800').split(',')]
 x,y=[v*scale for v in source]; dx,dy=[v*scale for v in destination]
 wait(.5);capture("settled.png");move(x,y);wait(.5);capture('before.png')
 call(r,p,r+'.Session.NotifyPointerButton',GLib.Variant('(ib)',(272,True)));pressed=True
 wait(.15)
 for i in range(1,11):
  move(x+(dx-x)*i/20,y+(dy-y)*i/20);wait(.08)
 wait(.5);capture('during.png')
 for i in range(11,21):
  move(x+(dx-x)*i/20,y+(dy-y)*i/20);wait(.06)
 wait(.3);capture('over-desktop.png')
 if columnMode and os.environ.get('DRAG_EXIT_POINT'):
  outside=[float(value)*scale for value in os.environ['DRAG_EXIT_POINT'].split(',')]
  move(*outside);wait(.12)
  states=[line.split('COLUMN_DROP_STATE ',1)[1].strip() for line in (target/'app.log').read_text().splitlines() if 'COLUMN_DROP_STATE ' in line]
  assert states and states[-1] == '[]', 'Highlight did not clear when pointer left the columns'
  move(dx,dy);wait(.2)
 call(r,p,r+'.Session.NotifyPointerButton',GLib.Variant('(ib)',(272,False)));pressed=False
 wait(1);capture('after.png')
 expected=target/os.environ.get('DRAG_EXPECTED_PATH',('source/' if fromChild else 'source/'+supportName+'/' if columnMode else 'desktop/')+entryName)
 assert expected.exists(), 'Native move failed; calibrate DRAG_SOURCE_POINT and DRAG_TARGET_POINT for this display'
 assert not sourceEntry.exists(), 'Native move left the source behind'
 if emptyFolder:assert expected.is_dir() and not list(expected.iterdir()), 'Empty folder did not retain its identity'
 wait(.1)
 import re
 trace=(target/'app.log').read_text()
 if columnMode:
  assert 'COLUMN_DROP_HIGHLIGHT ' in trace, 'Destination column never highlighted during native drag'
  states=[json.loads(value) for value in re.findall(r'COLUMN_DROP_STATE (\[[^\n]*?\])',trace)]
  assert states and states[-1] == [], 'Column highlight remained after native drag'
  assert all(len(state) <= 1 for state in states), 'Multiple columns highlighted during native drag'
  if os.environ.get('DRAG_REQUIRE_FOLDER_HIGHLIGHT'):assert 'FOLDER_DROP_FILL ' in trace, 'Folder row never showed a filled drop highlight'
 match=re.search(r'start_drag\(wl_data_source#\d+, wl_surface#\d+, wl_surface#(\d+),',trace)
 assert match, 'No native Wayland drag started'
 tail=trace[match.end():]
 assert 'wl_surface#'+match.group(1)+'.commit()' in tail, 'Drag feedback buffer never committed after start_drag'
 print('PASS: native pointer drag, post-role icon commit and file move; screenshots under '+str(target),flush=True)

finally:
 if pressed:
  call(r,p,r+'.Session.NotifyPointerButton',GLib.Variant('(ib)',(272,False)))
 if process:
  os.killpg(process.pid,signal.SIGTERM);process.wait(timeout=5)
 if pipeline:pipeline.set_state(Gst.State.NULL)
 if started:call(r,p,r+'.Session.Stop')

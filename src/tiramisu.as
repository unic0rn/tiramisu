import irc.InfoPanel;
import irc.LoginPanel;
import irc.NickPanel;
import irc.KeyPanel;
import irc.InvitePanel;
import irc.ChatArea;
import irc.SideButton;
import irc.Userlist;
import irc.Soundfx;
import flash.net.URLLoader;
import flash.net.URLRequest;
import flash.net.Socket;
import com.hurlant.crypto.tls.TLSSocket;
import flash.net.SharedObject;
import flash.utils.setTimeout;
import flash.utils.getTimer;
import flash.system.Capabilities;
import mx.effects.Glow;
import mx.effects.EffectInstance;
import mx.events.StyleEvent;
import mx.events.DataGridEvent;
import flash.events.Event;
import mx.core.UIComponent;
import flash.geom.Point;
import mx.events.ItemClickEvent;

internal var version:String = '[House Edition]';
internal var config:XML;
internal var commands:XML;
internal var cfgloader:URLLoader;
internal var sconf:SharedObject;
internal var btns:Array;
internal var users:Array;
internal var tusers:Array;
internal var tstamps:Array;
internal var cmdh:Array;
internal var windows:Array;
internal var topics:Array;
internal var modes:Array;
internal var mmodes:Array;
internal var tabso:Object;
internal var s:Socket;
internal var active:String;
internal var serv:String = 'status';
internal var inchange:Boolean = false;
internal var mynick:String;
internal var umode:String = '+';
internal var chans:Array;
internal var achans:Array;
internal var glows:Array;
internal var chanlist:Array;
internal var clupdate:Boolean = false;
internal var uniqueidx:uint = 0;
internal var cmdpos:int = 0;
internal var npf:String = '@+';
internal var mpf:String = 'ov';
internal var cpf:String = '#';
internal var cm:Array;
internal var scmsg:String = 'Server closed the connection.';
internal var pline:String;
internal var fe:String = '</font>';
internal var glowfx:Glow;
internal var cskin:String;
internal var uupdate:Boolean = false;
internal var lastping:int = 0;
internal var backlog:int = 200;
internal var tabhide:Boolean = false;
internal var tabmouse:Number = 0;
internal var reconnwait:Boolean = false;
internal var nicklen:int = 9;
internal var lastadd:int = 0;
internal var stylemanager:IStyleManager2;

internal function mutetoggle():void {
    if (!Soundfx.mute) {
        Soundfx.mute = true;
    } else {
        Soundfx.mute = false;
    }
}

internal function menuclick(e:ItemClickEvent):void {
}

internal function fb(f:String):String {
    return '<font color=\"'+getcsscolor('tiramisu',f)+'\">';
}

internal function tabs(idx:String):* {
    return tabso[idx.toLowerCase()];
}

internal function btnbarvalidate():void {
    if (btns == null) {
        return;
    }
    if (active == 'chanlist') {
        return;
    }
    btnbar.height = cmdline.y+cmdline.height-topic.y-1;
    var tmpw:Number = 0;
    for each(var tmpb:SideButton in btns) {
        if ((tmpb.minWidth > tmpw) && (tmpb.parent != null)) {
            tmpw = tmpb.minWidth;
        }
    }
    tmpw += 16;
    if (tmpw > (panel.width/6)) {
        tmpw = panel.width/6;
    }
    for each(tmpb in btns) {
        tmpb.width = tmpw;
    }
    if (btnbar.verticalScrollBar == null) {
        btnbar.width = tmpw;
    } else {
        btnbar.width = tmpw+20;
    }
    var tmpdiv:Number = 5+((1024-(1024-panel.width))/512-1)*2;
    if (tmpdiv < 5) {
        tmpdiv = 5;
    }
    if (tmpdiv > 7) {
        tmpdiv = 7;
    }
    ul.width = panel.width/tmpdiv;
    ulcount.width = panel.width/tmpdiv;
}

internal function appinit():void {
    stage.showDefaultContextMenu = false;
    stylemanager = StyleManager.getStyleManager(null);
    panel.title = 'tiramisu '+version;
    ul.npf = npf;
    cfgloader = new URLLoader();
    cfgloader.addEventListener('complete',cfgpreloaded);
    cfgloader.addEventListener('ioError',cfgerror);
    cfgloader.load(new URLRequest('config.xml?id='+getTimer()));
}

internal function cfgpreloaded(e:Event):void {
    config = new XML(cfgloader.data);
    cfgloader = new URLLoader();
    cfgloader.addEventListener('complete',cfgpreloaded2);
    cfgloader.addEventListener('ioError',cfgerror);
    cfgloader.load(new URLRequest('commands.xml?id='+getTimer()));
}

internal function cfgpreloaded2(e:Event):void {
    commands = new XML(cfgloader.data);
    cskin = config.ui.@skin;
    stylemanager.loadStyleDeclarations('skins/'+cskin+'.swf').addEventListener(StyleEvent.COMPLETE,cfgloaded);
}

internal function lockdown():void {
    visible = false;
}

internal function cfgloaded(e:Event):void {
    sconf = LoginPanel.userdata;
    btns = new Array();
    users = new Array();
    tusers = new Array();
    tstamps = new Array();
    cmdh = new Array();
    windows = new Array();
    topics = new Array();
    modes = new Array();
    mmodes = new Array();
    tabso = new Object();
    glows = new Array();
    glowfx = new Glow();
    if (sconf.data.chans == null) {
        chans = new Array();
    } else {
        chans = sconf.data.chans;
    }
    achans = new Array();
    cm = new Array();
    cm[0] = 'b';
    cm[1] = 'k';
    cm[2] = 'l';
    cm[3] = 'imnpst';
    if (config.core.@debug == 'true') {
        addstab('debug');
        addstab('unhandled');
    }
    addstab('status');
    addstab('chanlist');
    btns[uniqueidx-1].updatebtninit(chanlistupdate);
    cl.addEventListener('doubleClick',chanlistclick);
    setTimeout(clupdater,500);
    tabswitch('status');
    addEventListener('keyDown',keylistener);
    addEventListener('mouseMove',mouselistener);
    if (loaderInfo.parameters['nick'] != null) {
        sconf.data.nickname = loaderInfo.parameters['nick'];
    }
    setTimeout(LoginPanel.show,50,config,this,connect);
}

internal function clupdater():void {
    if (clupdate) {
        cl.dataProvider = chanlist;
        cl.columns[1].sortDescending = true;
        cl.dispatchEvent(new DataGridEvent(DataGridEvent.HEADER_RELEASE,false,false,1));
    }
    setTimeout(clupdater,500);
}

internal function chanlistclick(e:Event):void {
    if (cl.selectedItem != null) {
        swrite('JOIN '+cl.selectedItem.channel);
    }
}

internal function mouselistener(e:MouseEvent):void {
    tabmouse = e.stageX;
    if (tabhide) {
        if (tabmouse < 140) {
            btnbar.visible = true;
            btnbar.includeInLayout = true;
        } else {
            btnbar.visible = false;
            btnbar.includeInLayout = false;
        }
    }
}

internal function keylistener(e:KeyboardEvent):void {
    if (e.ctrlKey) {
        var k:uint = e.keyCode;
        if (k == 48) {
            k = 58;
        }
        var ptr:int = 49;
        var btns2:Array = sbar.getChildren().concat(cbar.getChildren().concat(qbar.getChildren()));
        for each(var b:SideButton in btns2) {
            if ((k-ptr) == 0) {
                tabswitch(b.label);
            }
            ptr++;
        }
    }
    var cmdhl:int = cmdh[tabs(active)].length;
    if (cmdhl > 0) {
        if (e.keyCode == 38) {
            cmdpos++;
            if ((cmdhl-cmdpos) >= 0) {
                cmdline.text = cmdh[tabs(active)][cmdhl-cmdpos];
                var cpos:int = cmdline.text.length;
                cmdline.setSelection(cpos,cpos);
            } else {
                cmdpos--;
            }
        }
        if (e.keyCode == 40) {
            cmdpos--;
            if (cmdpos >= 0) {
                cmdline.text = cmdh[tabs(active)][cmdhl-cmdpos];
                cpos = cmdline.text.length;
                cmdline.setSelection(cpos,cpos);
            } else {
                cmdpos = 0;
            }
        }
    }
    if (e.keyCode == 9) {
        var tscan:Array = new Array(active);
        for each(var u:String in users[tabs(active)]) {
            if (npf.indexOf(u.charAt(0)) != -1) {
                tscan.push(u.slice(1));
            } else {
                tscan.push(u);
            }
        }
        cpos = cmdline.selectionBeginIndex;
        var nb:int = cmdline.text.lastIndexOf(' ',cpos)+1;
        var tn:String = cmdline.text.slice(nb,cpos);
        var tn2:String = tn;
        var ts:int = 0;
        if (tn.length > 0) {
            for each(u in tscan) {
                if (u.toLowerCase().indexOf(tn.toLowerCase()) == 0) {
                    if (ts == 0) {
                        tn2 = u;
                        if (tstamps[tabs(active)][u.toLowerCase()] != null) {
                            ts = tstamps[tabs(active)][u.toLowerCase()];
                        }
                    } else if (tstamps[tabs(active)][u.toLowerCase()] > ts) {
                        tn2 = u;
                        ts = tstamps[tabs(active)][u.toLowerCase()];
                    }
                }
            }
            if (nb == 0) {
                tn2 += ': ';
            } else {
                tn2 += ' ';
            }
            cmdline.text = cmdline.text.slice(0,nb)+tn2+cmdline.text.slice(cpos);
            cpos = nb+tn2.length;
            cmdline.setSelection(cpos,cpos);
        }
    }
    if (focusManager.getFocus() != topic) {
        cmdline.setFocus();
    }
}

internal function connect():void {
    Security.loadPolicyFile('xmlsocket://'+config.server.@address+':'+config.server.@policyport);
    if (Security.sandboxType == Security.LOCAL_TRUSTED) {
        if (sconf.data.server.indexOf(':+') > 0) {
            config.server.@ssl = 'true';
        }
    }
    if (config.server.@ssl == 'true') {
        s = new TLSSocket();
    } else {
        s = new Socket();
    }
    s.addEventListener('securityError',secerr);
    s.addEventListener('close',sclosed);
    s.addEventListener('ioError',sioerr);
    s.addEventListener('connect',connected);
    s.addEventListener('socketData',sdata);
    pline = '';
    if (Security.sandboxType == Security.LOCAL_TRUSTED) {
        var scs:String = sconf.data.server;
        if (scs.indexOf(':') == -1) {
            s.connect(sconf.data.server,6667);
        } else {
            s.connect(scs.slice(0,scs.indexOf(':')),int(scs.slice(scs.indexOf(':')+1)));
        }
    } else {
        s.connect(config.server.@address,int(config.server.@port));
    }
    cmdline.setFocus();
    stage.addEventListener("activate",cmdfocus);
}

internal function cmdfocus(e:Event):void {
    cmdline.setFocus();
}

internal function reconn():void {
    reconnwait = false;
    pline = '';
    umode = '+';
    npf = '@+';
    mpf = 'ov';
    cpf = '#';
    nicklen = 9;
    for each(var g:EffectInstance in glows) {
        if (g != null) {
            g.end();
        }
    }
    glows = new Array();
    if (Security.sandboxType == Security.LOCAL_TRUSTED) {
        var scs:String = sconf.data.server;
        if (scs.indexOf(':') == -1) {
            s.connect(sconf.data.server,6667);
        } else {
            s.connect(scs.slice(0,scs.indexOf(':')),int(scs.slice(scs.indexOf(':')+1)));
        }
    } else {
        s.connect(config.server.@address,int(config.server.@port));
    }
}

internal function connected(e:Event):void {
    if ((sconf.data.password != '') && (config.server.@services == 'true')) {
        swrite('PASS '+sconf.data.password);
    } else if (config.server.@gateway == 'true') {
        swrite('PASS gatewaypassword');
    }
    mynick = sconf.data.nickname;
    swrite('NICK '+mynick);
    if (config.server.@gateway == 'true') {
        swrite('USER tiramisu x x :');
    } else if (config.server.@realname == 'true') {
        swrite('USER tiramisu x x :'+sconf.data.realname);
    } else {
        swrite('USER tiramisu x x :'+loaderInfo.url.slice(0,loaderInfo.url.indexOf('/',7)+1));
    }
}

internal function renick():void {
    mynick = sconf.data.nickname;
    swrite('NICK '+mynick);
}

internal function swrite(d:String):void {
    if (Capabilities.version.indexOf('LNX') == -1) {
        s.writeMultiByte(d+'\n',config.server.@encoding);
    } else {
        s.writeUTFBytes(d+'\n');
    }
    s.flush();
    if (config.core.@debug == 'true') {
        windows[tabs('debug')] += '\n'+fb('dbgout')+'&lt;- '+fe+d.replace(/</g,'&lt;').replace(/>/g,'&gt;');
    }
}

internal function sread():Array {
    var tline:String;
    if (Capabilities.version.indexOf('LNX') == -1) {
        tline = pline+s.readMultiByte(s.bytesAvailable,config.server.@encoding);
    } else {
        tline = pline+s.readUTFBytes(s.bytesAvailable);
    }
    pline = tline.slice(tline.lastIndexOf('\n')+1);
    tline = tline.slice(0,tline.lastIndexOf('\n')+1);
    return tline.replace(/\r/g,'').replace(/</g,'&lt;').replace(/>/g,'&gt;').split(/\n/);
}

internal function setglow(d:Number,s:String):void {
    glowfx.alphaFrom = 1;
    glowfx.alphaTo = 0;
    glowfx.strength = 4;
    glowfx.duration = d;
    glowfx.repeatCount = 0;
    glowfx.color = stylemanager.getStyleDeclaration('tiramisu').getStyle(s);
}

internal function cc(tline:String):String {
    var tline2:String = '';
    var tr:String = tline;
    if ((tline.indexOf('\u0002') != -1) || (tline.indexOf('\u0003') != -1) || (tline.indexOf('\u000f') != -1) || (tline.indexOf('\u0016') != -1) || (tline.indexOf('\u001f') != -1)) {
        var tbold:int = 0;
        var tcolor:int = 0;
        var tunder:int = 0;
        var tboldpos:int = -1;
        var tcolorpos:int = -1;
        var tunderpos:int = -1;
        var tcs:String;
        for (var tidx:int = 0; tidx < tline.length; tidx++) {
            if (tline.charAt(tidx) == '\u0002') {
                if (!tbold) {
                    tbold++;
                    tboldpos = tidx;
                    tline2 += '<b>';
                } else {
                    if (tunder && (tunderpos > tboldpos)) {
                        tunder--;
                        tunderpos = -1;
                        tline2 += '</u>';
                    }
                    if (tcolor && (tcolorpos > tboldpos)) {
                        tcolor--;
                        tcolorpos = -1;
                        tline2 += fe;
                    }
                    tbold--;
                    tboldpos = -1;
                    tline2 += '</b>';
                }
            } else if (tline.charAt(tidx) == '\u0003') {
                if (!tcolor) {
                    tcs = '';
                    for (var tidxc:int = tidx+1; tidxc < tline.length; tidxc++) {
                        if (((tline.charAt(tidxc) < '0') || (tline.charAt(tidxc) > '9')) && (tline.charAt(tidxc) != ',')) {
                            if (tcs.indexOf(',') != -1) {
                                tcs = tcs.slice(0,tcs.indexOf(','));
                            }
                            if ((tcs.length > 0) && (int(tcs) < 16)) {
                                tcolor++;
                                tcolorpos = tidx;
                                if (tcs.length == 1) {
                                    tcs = '0'+tcs;
                                }
                                tline2 += fb('mirc'+tcs);
                                tidx = tidxc-1;
                            }
                            break;
                        } else {
                            tcs += tline.charAt(tidxc);
                        }
                    }
                } else {
                    if (tunder && (tunderpos > tcolorpos)) {
                        tunder--;
                        tunderpos = -1;
                        tline2 += '</u>';
                    }
                    if (tbold && (tboldpos > tcolorpos)) {
                        tbold--;
                        tboldpos = -1;
                        tline2 += '</b>';
                    }
                    tcolor--;
                    tcolorpos = -1;
                    tline2 += fe;
                    tcs = '';
                    for (tidxc = tidx+1; tidxc < tline.length; tidxc++) {
                        if (((tline.charAt(tidxc) < '0') || (tline.charAt(tidxc) > '9')) && (tline.charAt(tidxc) != ',')) {
                            if ((tcs.length > 0) && (int(tcs) < 16)) {
                                tcolor++;
                                tcolorpos = tidx;
                                if (tcs.indexOf(',') != -1) {
                                    tcs = tcs.slice(0,tcs.indexOf(','));
                                }
                                if (tcs.length == 1) {
                                    tcs = '0'+tcs;
                                }
                                tline2 += fb('mirc'+tcs);
                                tidx = tidxc-1;
                            }
                            break;
                        } else {
                            tcs += tline.charAt(tidxc);
                        }
                    }
                }
            } else if (tline.charAt(tidx) == '\u000f') {
                for (var i:int=0; i<3; i++) {
                    if (tbold && (tboldpos > tcolorpos) && (tboldpos > tunderpos)) {
                        tbold--;
                        tboldpos = -1;
                        tline2 += '</b>';
                    }
                    if (tcolor && (tcolorpos > tboldpos) && (tcolorpos > tunderpos)) {
                        tcolor--;
                        tcolorpos = -1;
                        tline2 += fe;
                    }
                    if (tunder && (tunderpos > tboldpos) && (tunderpos > tcolorpos)) {
                        tunder--;
                        tunderpos = -1;
                        tline2 += '</u>';
                    }
                }
            } else if (tline.charAt(tidx) == '\u0016') {
            } else if (tline.charAt(tidx) == '\u001f') {
                if (!tunder) {
                    tunder++;
                    tunderpos = tidx;
                    tline2 += '<u>';
                } else {
                    if (tbold && (tboldpos > tunderpos)) {
                        tbold--;
                        tboldpos = -1;
                        tline2 += '</b>';
                    }
                    if (tcolor && (tcolorpos > tunderpos)) {
                        tcolor--;
                        tcolorpos = -1;
                        tline2 += fe;
                    }
                    tunder--;
                    tunderpos = -1;
                    tline2 += '</u>';
                }
            } else {
                tline2 += tline.charAt(tidx);
            }
        }
        while (tbold || tcolor || tunder) {
            if (tbold && (tboldpos > tcolorpos) && (tboldpos > tunderpos)) {
                tbold = 0;
                tboldpos -= 10000;
                tline2 += '</b>';
            }
            if (tcolor && (tcolorpos > tboldpos) && (tcolorpos > tunderpos)) {
                tcolor = 0;
                tcolorpos -= 10000;
                tline2 += fe;
            }
            if (tunder && (tunderpos > tboldpos) && (tunderpos > tcolorpos)) {
                tunder = 0;
                tunderpos -= 10000;
                tline2 += '</u>';
            }
        }
        tr = tline2;
    }
    return tr;
}

internal function hlcheck(hltr:String):Boolean {
    var hlidx:int = hltr.toLowerCase().indexOf(mynick.toLowerCase());
    if (hlidx == -1) {
        return true;
    } else {
        if (hlidx > 0) {
            if ((hltr.toLowerCase().charAt(hlidx-1) >= 'a') && (hltr.toLowerCase().charAt(hlidx-1) <= 'z')) {
                return true;
            }
        }
        if ((hlidx+mynick.length) < hltr.length) {
            if ((hltr.toLowerCase().charAt(hlidx+mynick.length) >= 'a') && (hltr.toLowerCase().charAt(hlidx+mynick.length) <= 'z')) {
                return true;
            }
        }
        return false;
    }
}

internal function urlcheck(utr:String):String {
    var utmp:String = utr;
    var uurl:String = '';
    var uidx:int = 0;
    var ucidx1:int;
    var ucidx2:int;
    var ucidx3:int;
    while (utmp.indexOf('http://',uidx) != -1) {
        uidx = utmp.indexOf('http://',uidx);
        ucidx1 = utmp.indexOf('"',uidx);
        ucidx2 = utmp.indexOf(' ',uidx);
        ucidx3 = utmp.indexOf('<',uidx);
        if (ucidx1 == -1) {
            ucidx1 = 9999;
        }
        if (ucidx2 == -1) {
            ucidx2 = 9999;
        }
        if (ucidx3 == -1) {
            ucidx3 = 9999;
        }
        if ((ucidx1 < ucidx2) && (ucidx1 < ucidx3)) {
            uurl = utmp.slice(uidx,ucidx1);
        } else if ((ucidx2 < ucidx1) && (ucidx2 < ucidx3)) {
            uurl = utmp.slice(uidx,ucidx2);
        } else if ((ucidx3 < ucidx1) && (ucidx3 < ucidx2)) {
            uurl = utmp.slice(uidx,ucidx3);
        } else {
            uurl = utmp.slice(uidx);
        }
        if ((uurl.charAt(uurl.length-1) == ',') || (uurl.charAt(uurl.length-1) == '.')) {
            uurl = uurl.slice(0,uurl.length-1);
        }
        utmp = utmp.slice(0,uidx)+'<a target=\"_blank\" href=\"'+uurl+'\">'+uurl+'</a>'+utmp.slice(uidx+uurl.length);
        uidx += 2*uurl.length+31;
    }
    uidx = 0;
    while (utmp.indexOf('https://',uidx) != -1) {
        uidx = utmp.indexOf('https://',uidx);
        ucidx1 = utmp.indexOf('"',uidx);
        ucidx2 = utmp.indexOf(' ',uidx);
        ucidx3 = utmp.indexOf('<',uidx);
        if (ucidx1 == -1) {
            ucidx1 = 9999;
        }
        if (ucidx2 == -1) {
            ucidx2 = 9999;
        }
        if (ucidx3 == -1) {
            ucidx3 = 9999;
        }
        if ((ucidx1 < ucidx2) && (ucidx1 < ucidx3)) {
            uurl = utmp.slice(uidx,ucidx1);
        } else if ((ucidx2 < ucidx1) && (ucidx2 < ucidx3)) {
            uurl = utmp.slice(uidx,ucidx2);
        } else if ((ucidx3 < ucidx1) && (ucidx3 < ucidx2)) {
            uurl = utmp.slice(uidx,ucidx3);
        } else {
            uurl = utmp.slice(uidx);
        }
        if ((uurl.charAt(uurl.length-1) == ',') || (uurl.charAt(uurl.length-1) == '.')) {
            uurl = uurl.slice(0,uurl.length-1);
        }
        utmp = utmp.slice(0,uidx)+'<a target=\"_blank\" href=\"'+uurl+'\">'+uurl+'</a>'+utmp.slice(uidx+uurl.length);
        uidx += 2*uurl.length+31;
    }
    uidx = 0;
    while (utmp.indexOf('ftp://',uidx) != -1) {
        uidx = utmp.indexOf('ftp://',uidx);
        ucidx1 = utmp.indexOf('"',uidx);
        ucidx2 = utmp.indexOf(' ',uidx);
        ucidx3 = utmp.indexOf('<',uidx);
        if (ucidx1 == -1) {
            ucidx1 = 9999;
        }
        if (ucidx2 == -1) {
            ucidx2 = 9999;
        }
        if (ucidx3 == -1) {
            ucidx3 = 9999;
        }
        if ((ucidx1 < ucidx2) && (ucidx1 < ucidx3)) {
            uurl = utmp.slice(uidx,ucidx1);
        } else if ((ucidx2 < ucidx1) && (ucidx2 < ucidx3)) {
            uurl = utmp.slice(uidx,ucidx2);
        } else if ((ucidx3 < ucidx1) && (ucidx3 < ucidx2)) {
            uurl = utmp.slice(uidx,ucidx3);
        } else {
            uurl = utmp.slice(uidx);
        }
        if ((uurl.charAt(uurl.length-1) == ',') || (uurl.charAt(uurl.length-1) == '.')) {
            uurl = uurl.slice(0,uurl.length-1);
        }
        utmp = utmp.slice(0,uidx)+'<a target=\"_blank\" href=\"'+uurl+'\">'+uurl+'</a>'+utmp.slice(uidx+uurl.length);
        uidx += 2*uurl.length+31;
    }
    return utmp;
}

internal function sdata(e:ProgressEvent):void {
    var tlines:Array = sread();
    var tidx:int;
    for each(var tline:String in tlines) {
        if (tline != '') {
            if (config.core.@debug == 'true') {
                windows[tabs('debug')] += '\n'+fb('dbgin')+'-&gt; '+fe+cc(tline);
            }
            if (tline.indexOf(':') == 0) {
                var t1:int = tline.indexOf(' ');
                var t2:int = tline.indexOf(' ',t1+1);
                var sender:String = tline.slice(1,t1);
                var cmd:String = tline.slice(t1+1,t2);
            } else {
                t2 = tline.indexOf(' ');
                sender = serv;
                cmd = tline.slice(0,t2);
            }
            var t3:int = tline.indexOf(' ',t2+1);
            var t4:int = tline.indexOf(' :',1);
            if (t3 == -1) {
                t3 = tline.length;
            }
            if (t4 == -1) {
                t4 = tline.length;
            }
            var target:String = tline.slice(t2+1,t3);
            var params:Array = tline.slice(t3+1,t4).split(/ /);
            var trailing:String = tline.slice(t4+2);
            var snick:String;
            if (sender.indexOf('!') > 0) {
                snick = sender.slice(0,sender.indexOf('!'));
            } else {
                snick = sender;
            }
            if (serv == 'status') {
                serv = sender;
            }
            while ((params.length > 1) && (params[0] == '')) {
                params.shift();
            }
            while ((params.length > 1) && (params[params.length-1] == '')) {
                params.pop();
            }
            var td:Date = new Date();
            var tdh:String = td.getHours().toString();
            var tdm:String = td.getMinutes().toString();
            var tds:String = td.getSeconds().toString();
            if (tdh.length == 1) {
                tdh = '0'+tdh;
            }
            if (tdm.length == 1) {
                tdm = '0'+tdm;
            }
            if (tds.length == 1) {
                tds = '0'+tds;
            }
            var tsmp:String = fb('time')+'['+tdh+':'+tdm+':'+tds+'] '+fe;
            switch (cmd) {
                case 'PRIVMSG':
                    switch (trailing) {
                        case '\u0001VERSION\u0001':
                            var release:String;
                            release = 'tiramisu '+version;
                            swrite('NOTICE '+snick+' :\u0001VERSION '+release+'\u0001');
                            if (target == mynick) {
                                windows[tabs(active)] += '\n'+tsmp+fb('notice')+'*** Received a CTCP VERSION from '+fe+snick;
                            } else {
                                windows[tabs(active)] += '\n'+tsmp+fb('notice')+'*** Received a CTCP VERSION from '+fe+snick+' '+fb('warn')+'('+fe+fb('hl')+'to '+target+fe+fb('warn')+')'+fe;
                            }
                            break;
                        case '\u0001PING\u0001':
                            swrite('NOTICE '+snick+' :\u0001PING\u0001');
                            if (target == mynick) {
                                windows[tabs(active)] += '\n'+tsmp+fb('notice')+'*** Received a CTCP PING from '+fe+snick;
                            } else {
                                windows[tabs(active)] += '\n'+tsmp+fb('notice')+'*** Received a CTCP PING from '+fe+snick+' '+fb('warn')+'('+fe+fb('hl')+'to '+target+fe+fb('warn')+')'+fe;
                            }
                            break;
                        default:
                            if ((trailing.indexOf('\u0001') == 0) && (trailing.indexOf('\u0001ACTION') != 0)) {
                                if (target == mynick) {
                                    windows[tabs(active)] += '\n'+tsmp+fb('notice')+'*** Received unknown CTCP request from '+fe+snick;
                                } else {
                                    windows[tabs(active)] += '\n'+tsmp+fb('notice')+'*** Received unknown CTCP request from '+fe+snick+' '+fb('warn')+'('+fe+fb('hl')+'to '+target+fe+fb('warn')+')'+fe;
                                }
                                break;
                            }
                            var gs:Boolean = false;
                            if (target.toLowerCase() == mynick.toLowerCase()) {
                                target = snick;
                                if (tabs(target) == null) {
                                    addqtab(target);
                                }
                                topics[tabs(target)] = cc(sender);
                                gs = true;
                            } else {
                                if (tabs(target) == null) {
                                    addctab(target);
                                }
                            }
                            if (trailing.indexOf('\u0001ACTION') != 0) {
                                if (hlcheck(trailing)) {
                                    windows[tabs(target)] += '\n'+tsmp+fb('nick')+'&lt;'+fe+snick+fb('nick')+'&gt; '+fe+urlcheck(cc(trailing));
                                } else {
                                    windows[tabs(target)] += '\n'+tsmp+fb('nick')+'&lt;'+fe+fb('hl')+snick+fe+fb('nick')+'&gt; '+fe+fb('hl')+urlcheck(cc(trailing))+fe;
                                    gs = true;
                                }
                            } else {
                                if (hlcheck(trailing)) {
                                    windows[tabs(target)] += '\n'+tsmp+fb('nick')+'* '+fe+snick+urlcheck(cc(trailing.slice(7,trailing.length-1)));
                                } else {
                                    windows[tabs(target)] += '\n'+tsmp+fb('nick')+'* '+fe+fb('hl')+snick+urlcheck(cc(trailing.slice(7,trailing.length-1)))+fe;
                                    gs = true;
                                }
                            }
                            tstamps[tabs(target)][snick.toLowerCase()] = getTimer();

                            if ((target.toLowerCase() == mynick.toLowerCase()) || gs) {
                                Soundfx.play();
                            }

                            if (target.toLowerCase() != active) {
                                if (glows[tabs(target)] != null) {
                                    if (glows[tabs(target)].duration == 2000) {
                                        glows[tabs(target)].end();
                                    } else {
                                        break;
                                    }
                                }
                                if (gs) {
                                    setglow(1000,'glow');
                                } else {
                                    setglow(2000,'glow2');
                                }
                                glows[tabs(target)] = glowfx.play(new Array(btns[tabs(target)]))[0];
                            }
                    }
                    break;
                case 'NOTICE':
                    if (target == mynick) {
                        if (trailing.indexOf('\u0001') != 0) {
                            windows[tabs(active)] += '\n'+tsmp+fb('nick')+'-'+fe+snick+fb('nick')+'- '+fe+fb('notice')+urlcheck(cc(trailing))+fe;
                        } else {
                            var ctcpt:String = trailing.slice(1,trailing.indexOf(' ')).toUpperCase();
                            if (ctcpt == 'PING') {
                                windows[tabs(active)] += '\n'+tsmp+fb('notice')+'*** CTCP '+ctcpt+' reply from '+fe+snick+fb('notice')+': '+(getTimer()-lastping)+'ms'+fe;
                            } else {
                                windows[tabs(active)] += '\n'+tsmp+fb('notice')+'*** CTCP '+ctcpt+' reply from '+fe+snick+fb('notice')+': '+urlcheck(cc(trailing.slice(trailing.indexOf(' ')+1,trailing.length-1)))+fe;
                            }
                        }
                    } else {
                        if (trailing.indexOf('\u0001') != 0) {
                            if (tabs(target) == null) {
                                windows[tabs('status')] += '\n'+tsmp+fb('nick')+'-'+fe+snick+'/'+target+fb('nick')+'- '+fe+fb('notice')+urlcheck(cc(trailing))+fe;
                                if (active != 'status') {
                                    windows[tabs(active)] += '\n'+tsmp+fb('nick')+'-'+fe+snick+'/'+target+fb('nick')+'- '+fe+fb('notice')+urlcheck(cc(trailing))+fe;
                                }
                            } else {
                                windows[tabs(target)] += '\n'+tsmp+fb('nick')+'-'+fe+snick+'/'+target+fb('nick')+'- '+fe+fb('notice')+urlcheck(cc(trailing))+fe;
                            }
                        } else {
                            if (tabs(target) == null) {
                                windows[tabs('status')] += '\n'+tsmp+fb('notice')+'*** CTCP '+trailing.slice(1,trailing.indexOf(' ')).toUpperCase()+' reply from '+snick+'/'+target+': '+urlcheck(cc(trailing.slice(trailing.indexOf(' ')+1,trailing.length-1)))+fe;
                            } else {
                                windows[tabs(target)] += '\n'+tsmp+fb('notice')+'*** CTCP '+trailing.slice(1,trailing.indexOf(' ')).toUpperCase()+' reply from '+snick+'/'+target+': '+urlcheck(cc(trailing.slice(trailing.indexOf(' ')+1,trailing.length-1)))+fe;
                            }
                        }
                    }
                    break;
                case 'JOIN':
                    if (trailing == '') {
                        trailing = target;
                    }
                    if (snick == mynick) {
                        if (tabs(trailing) == null) {
                            addctab(trailing);
                        }
                        if (chans.indexOf(trailing) == -1) {
                            chans.push(trailing);
                            sconf.data.chans = chans;
                            sconf.flush();
                        }
                        achans.push(trailing.toLowerCase());
                        tabswitch(trailing);
                        windows[tabs(trailing)] += '\n'+tsmp+fb('info')+'*** Now talking on '+trailing+fe;
                        swrite('MODE '+trailing);
                    } else {
                        if (config.ui.@joinparthide != 'true') {
                            windows[tabs(trailing)] += '\n'+tsmp+fb('info2')+'*** '+snick+' ('+cc(sender.slice(sender.indexOf('!')+1))+') has joined '+trailing+fe;
                        }
                        mmodes[tabs(trailing)][snick] = null;
                        var tua2:Array = users[tabs(trailing)];
                        tua2.push(snick);
                        tua2.sort(Array.CASEINSENSITIVE);
                        users[tabs(trailing)] = new Array();
                        for (var i:int = 0; i < npf.length; i++) {
                            for each(var tu:String in tua2) {
                                if (tu.indexOf(npf.charAt(i)) == 0) {
                                    users[tabs(trailing)].push(tu);
                                }
                            }
                        }
                        var tb:Boolean;
                        for each(tu in tua2) {
                            tb = true;
                            for (i = 0; i < npf.length; i++) {
                                if (tu.indexOf(npf.charAt(i)) == 0) {
                                    tb = false;
                                }
                            }
                            if (tb) {
                                users[tabs(trailing)].push(tu);
                            }
                        }
                    }
                    uupdate = true;
                    break;
                case 'PART':
                    if (snick == mynick) {
                        chans.splice(chans.indexOf(target),1);
                        sconf.data.chans = chans;
                        sconf.flush();
                        achans.splice(achans.indexOf(target),1);
                        if (glows[tabs(target)] != null) {
                            glows[tabs(target)].end();
                            glows[tabs(target)] = null;
                        }
                        var tatimer:int = getTimer();
                        if ((tatimer-lastadd) > 300) {
                            lastadd = tatimer;
                            setTimeout(closetab2,20,target);
                        } else {
                            setTimeout(closetab2,300-(tatimer-lastadd)+20,target);
                            lastadd = tatimer+300-(tatimer-lastadd);
                        }
                        if (trailing == '') {
                            windows[tabs('status')] += '\n'+tsmp+fb('info2')+'*** You have left channel '+target+fe;
                        } else {
                            windows[tabs('status')] += '\n'+tsmp+fb('info2')+'*** You have left channel '+target+' ('+urlcheck(cc(trailing))+')'+fe;
                        }
                    } else {
                        if (config.ui.@joinparthide != 'true') {
                            if (trailing == '') {
                                windows[tabs(target)] += '\n'+tsmp+fb('info2')+'*** '+snick+' ('+cc(sender.slice(sender.indexOf('!')+1))+') has left '+target+fe;
                            } else {
                                windows[tabs(target)] += '\n'+tsmp+fb('info2')+'*** '+snick+' ('+cc(sender.slice(sender.indexOf('!')+1))+') has left '+target+' ('+urlcheck(cc(trailing))+')'+fe;
                            }
                        }
                        tidx = users[tabs(target)].indexOf(snick);
                        for (i = 0; i < npf.length; i++) {
                            if (tidx < 0) {
                                tidx = users[tabs(target)].indexOf(npf.charAt(i)+snick);
                            } else {
                                break;
                            }
                        }
                        users[tabs(target)].splice(tidx,1);
                    }
                    uupdate = true;
                    break;
                case 'KICK':
                    if (params[0] == mynick) {
                        chans.splice(chans.indexOf(target),1);
                        sconf.data.chans = chans;
                        sconf.flush();
                        achans.splice(achans.indexOf(target),1);
                        btns[tabs(target)].parent.removeChild(btns[tabs(target)]);
                        tabso[target.toLowerCase()] = null;
                        if (active == target.toLowerCase()) {
                            tabswitch('status');
                        }
                        windows[tabs('status')] += '\n'+tsmp+fb('warn')+'*** You have been kicked from '+target+' by '+snick+' ('+urlcheck(cc(trailing))+')'+fe;
                        if ((String(config.channels.@kickredirect).indexOf('#') == 0) && (String(config.channels.@autojoin).toLowerCase() == target.toLowerCase())) {
                            swrite('JOIN '+config.channels.@kickredirect);
                        }
                    } else {
                        if (config.ui.@joinparthide != 'true') {
                            windows[tabs(target)] += '\n'+tsmp+fb('warn')+'*** '+snick+' has kicked '+params[0]+' from '+target+' ('+urlcheck(cc(trailing))+')'+fe;
                        }
                        tidx = users[tabs(target)].indexOf(params[0]);
                        for (i = 0; i < npf.length; i++) {
                            if (tidx < 0) {
                                tidx = users[tabs(target)].indexOf(npf.charAt(i)+params[0]);
                            } else {
                                break;
                            }
                        }
                        users[tabs(target)].splice(tidx,1);
                    }
                    uupdate = true;
                    break;
                case 'TOPIC':
                    topics[tabs(target)] = cc(trailing);
                    windows[tabs(target)] += '\n'+tsmp+fb('info')+'*** '+snick+' has changed the topic to: '+urlcheck(cc(trailing))+fe;
                    break;
                case 'PING':
                    swrite('PONG :'+trailing);
                    break;
                case 'ERROR':
                    scmsg = trailing;
                    break;
                case '321':
                    chanlist = new Array();
                    clupdate = true;
                    break;
                case '322':
                    var tmpchan:Object = new Object();
                    tmpchan.channel = params[0];
                    tmpchan.users = int(params[1]);
                    if (trailing.indexOf('[+') == 0) {
                        tmpchan.modes = trailing.slice(1,trailing.indexOf(']'));
                        tmpchan.topic = cc(trailing.slice(trailing.indexOf(']')+1));
                    } else {
                        tmpchan.modes = '';
                        tmpchan.topic = cc(trailing);
                    }
                    chanlist.push(tmpchan);
                    break;
                case '323':
                    clupdate = false;
                    cl.dataProvider = chanlist;
                    cl.columns[1].sortDescending = true;
                    cl.dispatchEvent(new DataGridEvent(DataGridEvent.HEADER_RELEASE,false,false,1));
                    break;
                case 'KILL':
                case '436':
                    achans = new Array();
                    windows[tabs(active)] += '\n'+tsmp+fb('warn')+'*** You have been killed by '+snick+' ('+urlcheck(cc(trailing))+')'+fe;
                    if (active != 'status') {
                        windows[tabs('status')] += '\n'+tsmp+fb('warn')+'*** You have been killed by '+snick+' ('+urlcheck(cc(trailing))+')'+fe;
                    }
                    break;
                case 'QUIT':
                    if (snick == mynick) {
                        achans = new Array();
                        tabswitch('status');
                        windows[tabs('status')] += '\n'+tsmp+fb('warn')+'*** Disconnected ('+urlcheck(cc(trailing))+').'+fe;
                        serv = 'status';
                    } else {
                        for each(var ta:Array in users) {
                            tidx = ta.indexOf(snick);
                            tidx2 = users.indexOf(ta);
                            for (i = 0; i < npf.length; i++) {
                                if (tidx < 0) {
                                    tidx = ta.indexOf(npf.charAt(i)+snick);
                                } else {
                                    break;
                                }
                            }
                            if (tidx != -1) {
                                if (config.ui.@joinparthide != 'true') {
                                    windows[tidx2] += '\n'+tsmp+fb('info2')+'*** '+snick+' has quit ('+urlcheck(cc(trailing))+')'+fe;
                                }
                                users[tidx2].splice(tidx,1);
                            }
                        }
                    }
                    uupdate = true;
                    break;
                case 'NICK':
                    if (trailing == '') {
                        trailing = target;
                    }
                    if (snick == mynick) {
                        windows[tabs(active)] += '\n'+tsmp+fb('nickchg')+'*** You are now known as '+trailing+fe;
                    } else {
                        if (tabs(snick) != null) {
                            windows[tabs(snick)] += '\n'+tsmp+fb('nickchg')+'*** '+snick+' is now known as '+trailing+fe;
                            rentab(snick,trailing);
                        }
                    }
                    var tidx2:int;
                    for each(ta in users) {
                        tidx = ta.indexOf(snick);
                        tidx2 = users.indexOf(ta);
                        var ts:String = '';
                        for (i = 0; i < npf.length; i++) {
                            if (tidx < 0) {
                                tidx = ta.indexOf(npf.charAt(i)+snick);
                                ts = npf.charAt(i);
                            } else {
                                break;
                            }
                        }
                        if (tidx != -1) {
                            if (snick != mynick) {
                                windows[tidx2] += '\n'+tsmp+fb('nickchg')+'*** '+snick+' is now known as '+trailing+fe;
                            }
                            mmodes[tidx2][trailing] = mmodes[tidx2][snick];
                            mmodes[tidx2][snick] = null;
                            ta.splice(tidx,1);
                            tua2 = ta;
                            tua2.push(ts+trailing);
                            tua2.sort(Array.CASEINSENSITIVE);
                            users[tidx2] = new Array();
                            for (i = 0; i < npf.length; i++) {
                                for each(tu in tua2) {
                                    if (tu.indexOf(npf.charAt(i)) == 0) {
                                        users[tidx2].push(tu);
                                    }
                                }
                            }
                            for each(tu in tua2) {
                                tb = true;
                                for (i = 0; i < npf.length; i++) {
                                    if (tu.indexOf(npf.charAt(i)) == 0) {
                                        tb = false;
                                    }
                                }
                                if (tb) {
                                    users[tidx2].push(tu);
                                }
                            }
                        }
                    }
                    if (snick == mynick) {
                        mynick = trailing;
                        titleupdate();
                    }
                    uupdate = true;
                    break;
                case 'INVITE':
                    InvitePanel.show(snick,trailing,this,invjoin);
                    break;
                case 'MODE':
                    var adding:Boolean = false;
                    var mchar:String;
                    if (target == mynick) {
                        if (trailing == '') {
                            trailing = params[0];
                        }
                        windows[tabs('status')] += '\n'+tsmp+fb('mode')+'*** '+snick+' sets mode '+trailing+' '+mynick+fe;
                        for (i = 0; i < trailing.length; i++) {
                            mchar = trailing.charAt(i);
                            if (mchar == '+') {
                                adding = true;
                            } else if (mchar == '-') {
                                adding = false;
                            } else {
                                if (adding) {
                                    if (umode.indexOf(mchar) == -1) {
                                        umode += mchar;
                                    }
                                } else {
                                    if (umode.indexOf(mchar) != -1) {
                                        umode = umode.replace(mchar,'');
                                    }
                                }
                            }
                        }
                    } else {
                        if (config.ui.@joinparthide != 'true') {
                            windows[tabs(target)] += '\n'+tsmp+fb('mode')+'*** '+snick+' sets mode '+params.join(' ')+fe;
                        }
                        var tmodes:Array = modes[tabs(target)].split(' ');
                        for (i = 0; i < params[0].length; i++) {
                            mchar = params[0].charAt(i);
                            if (mchar == '+') {
                                adding = true;
                            } else if (mchar == '-') {
                                adding = false;
                            } else {
                                if (adding) {
                                    if (cm[3].indexOf(mchar) != -1) {
                                        if (tmodes[0].indexOf(mchar) == -1) {
                                            tmodes[0] += mchar;
                                        }
                                    } else if ((cm[1].indexOf(mchar) != -1) || (cm[2].indexOf(mchar) != -1)) {
                                        if (tmodes[0].indexOf(mchar) == -1) {
                                            tmodes[0] += mchar;
                                            tmodes.push(params[1]);
                                            params.splice(1,1);
                                        }
                                    } else if (mpf.indexOf(mchar) != -1) {
                                        ta = users[tabs(target)];
                                        tidx = ta.indexOf(params[1]);
                                        ts = '';
                                        for (var i2:int = 0; i2 < npf.length; i2++) {
                                            if (tidx < 0) {
                                                tidx = ta.indexOf(npf.charAt(i2)+params[1]);
                                                ts = npf.charAt(i2);
                                            } else {
                                                break;
                                            }
                                        }
                                        if (tidx != -1) {
                                            var ts2:String = npf.charAt(mpf.indexOf(mchar));
                                            var mma:Array = mmodes[tabs(target)][params[1]];
                                            if (mma == null) {
                                                mma = new Array();
                                                for (i2 = 0; i2 < npf.length; i2++) {
                                                    mma.push('');
                                                }
                                            }
                                            if (ts != '') {
                                                mma[npf.indexOf(ts)] = ts;
                                            }
                                            mma[npf.indexOf(ts2)] = ts2;
                                            for (i2 = 0; i2 < mma.length; i2++) {
                                                if (mma[i2] != '') {
                                                    ts2 = mma[i2];
                                                    mma[i2] = '';
                                                    mmodes[tabs(target)][params[1]] = mma;
                                                    break;
                                                }
                                            }
                                            ta.splice(tidx,1);
                                            tua2 = ta;
                                            tua2.push(ts2+params[1]);
                                            tua2.sort(Array.CASEINSENSITIVE);
                                            users[tabs(target)] = new Array();
                                            for (i2 = 0; i2 < npf.length; i2++) {
                                                for each(tu in tua2) {
                                                    if (tu.indexOf(npf.charAt(i2)) == 0) {
                                                        users[tabs(target)].push(tu);
                                                    }
                                                }
                                            }
                                            for each(tu in tua2) {
                                                tb = true;
                                                for (i2 = 0; i2 < npf.length; i2++) {
                                                    if (tu.indexOf(npf.charAt(i2)) == 0) {
                                                        tb = false;
                                                    }
                                                }
                                                if (tb) {
                                                    users[tabs(target)].push(tu);
                                                }
                                            }
                                        }
                                        params.splice(1,1);
                                    } else {
                                        params.splice(1,1);
                                    }
                                } else {
                                    if (cm[3].indexOf(mchar) != -1) {
                                        if (tmodes[0].indexOf(mchar) != -1) {
                                            tmodes[0] = tmodes[0].replace(mchar,'');
                                        }
                                    } else if (cm[2].indexOf(mchar) != -1) {
                                        if (tmodes[0].indexOf(mchar) != -1) {
                                            var toff:int = 1;
                                            var tc:String;
                                            for (i2 = 0; i2 < tmodes[0].indexOf(mchar); i2++) {
                                                tc = tmodes[0].charAt(i2);
                                                if ((cm[1].indexOf(tc) != -1) || (cm[2].indexOf(tc) != -1)) {
                                                    toff++;
                                                }
                                            }
                                            tmodes[0] = tmodes[0].replace(mchar,'');
                                            tmodes.splice(toff,1);
                                        }
                                    } else if (cm[1].indexOf(mchar) != -1) {
                                        if (tmodes[0].indexOf(mchar) != -1) {
                                            toff = 1;
                                            for (i2 = 0; i2 < tmodes[0].indexOf(mchar); i2++) {
                                                tc = tmodes[0].charAt(i2);
                                                if ((cm[1].indexOf(tc) != -1) || (cm[2].indexOf(tc) != -1)) {
                                                    toff++;
                                                }
                                            }
                                            tmodes[0] = tmodes[0].replace(mchar,'');
                                            tmodes.splice(toff,1);
                                            params.splice(1,1);
                                        }
                                    } else if (mpf.indexOf(mchar) != -1) {
                                        ta = users[tabs(target)];
                                        tidx = ta.indexOf(params[1]);
                                        ts = '';
                                        for (i2 = 0; i2 < npf.length; i2++) {
                                            if (tidx < 0) {
                                                tidx = ta.indexOf(npf.charAt(i2)+params[1]);
                                                ts = npf.charAt(i2);
                                            } else {
                                                break;
                                            }
                                        }
                                        if (tidx != -1) {
                                            ts2 = npf.charAt(mpf.indexOf(mchar));
                                            mma = mmodes[tabs(target)][params[1]];
                                            if (mma == null) {
                                                mma = new Array();
                                                for (i2 = 0; i2 < npf.length; i2++) {
                                                    mma.push('');
                                                }
                                            }
                                            if (ts != '') {
                                                mma[npf.indexOf(ts)] = ts;
                                            }
                                            mma[npf.indexOf(ts2)] = '';
                                            ts2 = '';
                                            mmodes[tabs(target)][params[1]] = mma;
                                            for (i2 = 0; i2 < mma.length; i2++) {
                                                if (mma[i2] != '') {
                                                    ts2 = mma[i2];
                                                    mma[i2] = '';
                                                    mmodes[tabs(target)][params[1]] = mma;
                                                    break;
                                                }
                                            }
                                            ta.splice(tidx,1);
                                            tua2 = ta;
                                            tua2.push(ts2+params[1]);
                                            tua2.sort(Array.CASEINSENSITIVE);
                                            users[tabs(target)] = new Array();
                                            for (i2 = 0; i2 < npf.length; i2++) {
                                                for each(tu in tua2) {
                                                    if (tu.indexOf(npf.charAt(i2)) == 0) {
                                                        users[tabs(target)].push(tu);
                                                    }
                                                }
                                            }
                                            for each(tu in tua2) {
                                                tb = true;
                                                for (i2 = 0; i2 < npf.length; i2++) {
                                                    if (tu.indexOf(npf.charAt(i2)) == 0) {
                                                        tb = false;
                                                    }
                                                }
                                                if (tb) {
                                                    users[tabs(target)].push(tu);
                                                }
                                            }
                                        }
                                        params.splice(1,1);
                                    } else {
                                        params.splice(1,1);
                                    }
                                }
                            }
                        }
                        modes[tabs(target)] = tmodes.join(' ');
                    }
                    titleupdate();
                    uupdate = true;
                    break;
                case '001':
                    mynick = target;
                    if ((params.length == 0) || (params[0] == '')) {
                        windows[tabs('status')] += '\n'+tsmp+fb('notice')+urlcheck(cc(trailing))+fe;
                    } else {
                        windows[tabs('status')] += '\n'+tsmp+fb('notice')+params.join(' ')+' '+urlcheck(cc(trailing))+fe;
                    }
                    break;
                case '002':
                case '003':
                case '004':
                case '020':
                case '250':
                case '251':
                case '252':
                case '253':
                case '254':
                case '255':
                case '265':
                case '266':
                case '372':
                case '375':
                    if ((params.length == 0) || (params[0] == '')) {
                        windows[tabs('status')] += '\n'+tsmp+fb('notice')+urlcheck(cc(trailing))+fe;
                    } else {
                        windows[tabs('status')] += '\n'+tsmp+fb('notice')+params.join(' ')+' '+urlcheck(cc(trailing))+fe;
                    }
                    break;
                case '008':
                case '042':
                    windows[tabs('status')] += '\n'+tsmp+fb('notice')+'*** '+urlcheck(cc(trailing))+' '+params[0]+fe;
                    break;
                case '005':
                    var ti:int = tline.indexOf('PREFIX=');
                    if (ti != -1) {
                        mpf = tline.slice(tline.indexOf('(',ti)+1,tline.indexOf(')',ti));
                        npf = tline.slice(tline.indexOf(')',ti)+1,tline.indexOf(' ',ti));
                        ul.npf = npf;
                    }
                    ti = tline.indexOf('CHANTYPES=');
                    if (ti != -1) {
                        cpf = tline.slice(tline.indexOf('=',ti)+1,tline.indexOf(' ',ti));
                    }
                    ti = tline.indexOf('CHANMODES=');
                    if (ti != -1) {
                        cm = tline.slice(tline.indexOf('=',ti)+1,tline.indexOf(' ',ti)).split(',');
                    }
                    ti = tline.indexOf('NICKLEN=');
                    if (ti != -1) {
                        nicklen = int(tline.slice(tline.indexOf('=',ti)+1,tline.indexOf(' ',ti)));
                        if (mynick.length > nicklen) {
                            mynick = mynick.substr(0,nicklen);
                        }
                    }
                    break;
                case '221':
                    umode = params[0];
                    titleupdate();
                    break;
                case '263':
                case '401':
                case '402':
                case '403':
                case '404':
                case '405':
                case '406':
                case '407':
                case '408':
                case '413':
                case '414':
                case '415':
                case '421':
                case '437':
                case '442':
                case '444':
                case '461':
                case '472':
                    windows[tabs(active)] += '\n'+tsmp+fb('notice')+'*** '+params[0]+': '+urlcheck(cc(trailing))+fe;
                    if (active != 'status') {
                        windows[tabs('status')] += '\n'+tsmp+fb('notice')+'*** '+params[0]+': '+urlcheck(cc(trailing))+fe;
                    }
                    break;
                case '311':
                    windows[tabs(active)] += '\n'+tsmp+fb('notice')+'*** '+fe+params[0]+fb('notice')+' is '+urlcheck(cc(params[1]+'@'+params[2]+' ('+trailing+')'))+fe;
                    if (active != 'status') {
                        windows[tabs('status')] += '\n'+tsmp+fb('notice')+'*** '+fe+params[0]+fb('notice')+' is '+urlcheck(cc(params[0]+'!'+params[1]+'@'+params[2]+' ('+trailing+')'))+fe;
                    }
                    break;
                case '314':
                    windows[tabs(active)] += '\n'+tsmp+fb('notice')+'*** '+fe+params[0]+fb('notice')+' was '+urlcheck(cc(params[1]+'@'+params[2]+' ('+trailing+')'))+fe;
                    if (active != 'status') {
                        windows[tabs('status')] += '\n'+tsmp+fb('notice')+'*** '+fe+params[0]+fb('notice')+' was '+urlcheck(cc(params[0]+'!'+params[1]+'@'+params[2]+' ('+trailing+')'))+fe;
                    }
                    break;
                case '319':
                    windows[tabs(active)] += '\n'+tsmp+fb('notice')+'*** '+fe+params[0]+fb('notice')+' is on '+urlcheck(cc(trailing))+fe;
                    if (active != 'status') {
                        windows[tabs('status')] += '\n'+tsmp+fb('notice')+'*** '+fe+params[0]+fb('notice')+' is on '+urlcheck(cc(trailing))+fe;
                    }
                    break;
                case '312':
                    windows[tabs(active)] += '\n'+tsmp+fb('notice')+'*** '+fe+params[0]+fb('notice')+' on server '+urlcheck(cc(params[1]+' ('+trailing+')'))+fe;
                    if (active != 'status') {
                        windows[tabs('status')] += '\n'+tsmp+fb('notice')+'*** '+fe+params[0]+fb('notice')+' on server '+urlcheck(cc(params[1]+' ('+trailing+')'))+fe;
                    }
                    break;
                case '470':
                    windows[tabs(active)] += '\n'+tsmp+fb('notice')+'*** You\'ve been forwarded from '+fe+params[0]+fb('notice')+' to '+fe+params[1];
                    if (active != 'status') {
                        windows[tabs('status')] += '\n'+tsmp+fb('notice')+'*** You\'ve been forwarded from '+fe+params[0]+fb('notice')+' to '+fe+params[1];
                    }
                    break;              
                case '328':
                    windows[tabs(params[0])] += '\n'+tsmp+fb('info')+'*** Homepage: '+urlcheck(cc(trailing))+fe;
                    break;              
                case '275':
                case '307':
                case '310':
                case '313':
                case '320':
                case '326':
                case '335':
                case '378':
                case '379':
                case '671':
                case '672':
                    windows[tabs(active)] += '\n'+tsmp+fb('notice')+'*** '+fe+params[0]+fb('notice')+' '+urlcheck(cc(trailing))+fe;
                    if (active != 'status') {
                        windows[tabs('status')] += '\n'+tsmp+fb('notice')+'*** '+fe+params[0]+fb('notice')+' '+urlcheck(cc(trailing))+fe;
                    }
                    break;
                case '301':
                    windows[tabs(active)] += '\n'+tsmp+fb('notice')+'*** '+fe+params[0]+fb('notice')+' is away ('+urlcheck(cc(trailing))+')'+fe;
                    if (active != 'status') {
                        windows[tabs('status')] += '\n'+tsmp+fb('notice')+'*** '+fe+params[0]+fb('notice')+' is away ('+urlcheck(cc(trailing))+')'+fe;
                    }
                    break;
                case '330':
                case '338':
                    windows[tabs(active)] += '\n'+tsmp+fb('notice')+'*** '+fe+params[0]+fb('notice')+' '+urlcheck(cc(trailing+' '+params[1]))+fe;
                    if (active != 'status') {
                        windows[tabs('status')] += '\n'+tsmp+fb('notice')+'*** '+fe+params[0]+fb('notice')+' '+urlcheck(cc(trailing+' '+params[1]))+fe;
                    }
                    break;
                case '317':
                    var wh:int = Math.floor(params[1]/3600);
                    var wm:int = Math.floor((params[1]-wh*3600)/60);
                    var ws:int = params[1]-wh*3600-wm*60;
                    var whs:String = wh.toString();
                    var wms:String = wm.toString();
                    var wss:String = ws.toString();
                    if (whs.length == 1) {
                        whs = '0'+whs;
                    }
                    if (wms.length == 1) {
                        wms = '0'+wms;
                    }
                    if (wss.length == 1) {
                        wss = '0'+wss;
                    }
                    windows[tabs(active)] += '\n'+tsmp+fb('notice')+'*** '+fe+params[0]+fb('notice')+' has been idle for '+whs+':'+wms+':'+wss+', online since '+(new Date(params[2]*1000).toLocaleString())+fe;
                    if (active != 'status') {
                        windows[tabs('status')] += '\n'+tsmp+fb('notice')+'*** '+fe+params[0]+fb('notice')+' has been idle for '+whs+':'+wms+':'+wss+', online since '+(new Date(params[2]*1000).toLocaleString())+fe;
                    }
                    break;
                case '341':
                    windows[tabs(active)] += '\n'+tsmp+fb('notice')+'*** Inviting '+params[0]+' to '+params[1]+fe;
                    if (active != 'status') {
                        windows[tabs('status')] += '\n'+tsmp+fb('notice')+'*** Inviting '+params[0]+' to '+params[1]+fe;
                    }
                    break;
                case '346':
                    if (params[2] != null) {
                        windows[tabs(active)] += '\n'+tsmp+fb('notice')+'*** '+params[0]+' invex: '+params[1]+', set by '+params[2]+' on '+(new Date(params[3]*1000).toLocaleString())+fe;
                        if (active != 'status') {
                            windows[tabs('status')] += '\n'+tsmp+fb('notice')+'*** '+params[0]+' invex: '+params[1]+', set by '+params[2]+' on '+(new Date(params[3]*1000).toLocaleString())+fe;
                        }
                    } else {
                        windows[tabs(active)] += '\n'+tsmp+fb('notice')+'*** '+params[0]+' invex: '+params[1]+fe;
                        if (active != 'status') {
                            windows[tabs('status')] += '\n'+tsmp+fb('notice')+'*** '+params[0]+' invex: '+params[1]+fe;
                        }
                    }
                    break;
                case '348':
                    if (params[2] != null) {
                        windows[tabs(active)] += '\n'+tsmp+fb('notice')+'*** '+params[0]+' except: '+params[1]+', set by '+params[2]+' on '+(new Date(params[3]*1000).toLocaleString())+fe;
                        if (active != 'status') {
                            windows[tabs('status')] += '\n'+tsmp+fb('notice')+'*** '+params[0]+' except: '+params[1]+', set by '+params[2]+' on '+(new Date(params[3]*1000).toLocaleString())+fe;
                        }
                    } else {
                        windows[tabs(active)] += '\n'+tsmp+fb('notice')+'*** '+params[0]+' except: '+params[1]+fe;
                        if (active != 'status') {
                            windows[tabs('status')] += '\n'+tsmp+fb('notice')+'*** '+params[0]+' except: '+params[1]+fe;
                        }
                    }
                    break;
                case '367':
                    if (params[2] != null) {
                        windows[tabs(active)] += '\n'+tsmp+fb('notice')+'*** '+params[0]+' ban: '+params[1]+', set by '+params[2]+' on '+(new Date(params[3]*1000).toLocaleString())+fe;
                        if (active != 'status') {
                            windows[tabs('status')] += '\n'+tsmp+fb('notice')+'*** '+params[0]+' ban: '+params[1]+', set by '+params[2]+' on '+(new Date(params[3]*1000).toLocaleString())+fe;
                        }
                    } else {
                        windows[tabs(active)] += '\n'+tsmp+fb('notice')+'*** '+params[0]+' ban: '+params[1]+fe;
                        if (active != 'status') {
                            windows[tabs('status')] += '\n'+tsmp+fb('notice')+'*** '+params[0]+' ban: '+params[1]+fe;
                        }
                    }
                    break;
                case '344':
                    if (params[2] != null) {
                        windows[tabs(active)] += '\n'+tsmp+fb('notice')+'*** '+params[0]+' reop: '+params[1]+', set by '+params[2]+' on '+(new Date(params[3]*1000).toLocaleString())+fe;
                        if (active != 'status') {
                            windows[tabs('status')] += '\n'+tsmp+fb('notice')+'*** '+params[0]+' reop: '+params[1]+', set by '+params[2]+' on '+(new Date(params[3]*1000).toLocaleString())+fe;
                        }
                    } else {
                        windows[tabs(active)] += '\n'+tsmp+fb('notice')+'*** '+params[0]+' reop: '+params[1]+fe;
                        if (active != 'status') {
                            windows[tabs('status')] += '\n'+tsmp+fb('notice')+'*** '+params[0]+' reop: '+params[1]+fe;
                        }
                    }
                    break;
                case '396':
                    windows[tabs(active)] += '\n'+tsmp+fb('notice')+'*** '+urlcheck(cc(params[0]+' '+trailing))+fe;
                    if (active != 'status') {
                        windows[tabs('status')] += '\n'+tsmp+fb('notice')+'*** '+urlcheck(cc(params[0]+' '+trailing))+fe;
                    }
                    break;
                case '467':
                case '476':
                case '477':
                case '482':
                    windows[tabs(params[0])] += '\n'+tsmp+fb('notice')+'*** '+urlcheck(cc(trailing))+fe;
                    break;
                case '443':
                    windows[tabs(active)] += '\n'+tsmp+fb('notice')+'*** '+params[0]+' is already on '+params[1]+fe;
                    if (active != 'status') {
                        windows[tabs('status')] += '\n'+tsmp+fb('notice')+'*** '+params[0]+' is already on '+params[1]+fe;
                    }
                    break;
                case '478':
                    windows[tabs(params[0])] += '\n'+tsmp+fb('notice')+'*** '+trailing+' ('+params[1]+')'+fe;
                    break;
                case '471':
                    windows[tabs(active)] += '\n'+tsmp+fb('warn')+'*** Cannot join '+params[0]+' (channel limit exceeded)'+fe;
                    if (active != 'status') {
                        windows[tabs('status')] += '\n'+tsmp+fb('warn')+'*** Cannot join '+params[0]+' (channel limit exceeded)'+fe;
                    }
                    if (chans.indexOf(params[0]) != -1) {
                        chans.splice(chans.indexOf(params[0]),1);
                        sconf.data.chans = chans;
                        sconf.flush();
                        if (tabs(params[0]) != null) {
                            btns[tabs(params[0])].parent.removeChild(btns[tabs(params[0])]);
                            tabso[params[0].toLowerCase()] = null;
                        }
                        if (active == params[0].toLowerCase()) {
                            tabswitch('status');
                        }
                    }
                    break;
                case '473':
                    windows[tabs(active)] += '\n'+tsmp+fb('warn')+'*** Cannot join '+params[0]+' (channel is invite only)'+fe;
                    if (active != 'status') {
                        windows[tabs('status')] += '\n'+tsmp+fb('warn')+'*** Cannot join '+params[0]+' (channel is invite only)'+fe;
                    }
                    if (chans.indexOf(params[0]) != -1) {
                        chans.splice(chans.indexOf(params[0]),1);
                        sconf.data.chans = chans;
                        sconf.flush();
                        if (tabs(params[0]) != null) {
                            btns[tabs(params[0])].parent.removeChild(btns[tabs(params[0])]);
                            tabso[params[0].toLowerCase()] = null;
                        }
                        if (active == params[0].toLowerCase()) {
                            tabswitch('status');
                        }
                    }
                    break;
                case '474':
                    windows[tabs(active)] += '\n'+tsmp+fb('warn')+'*** Cannot join '+params[0]+' (you\'re banned)'+fe;
                    if (active != 'status') {
                        windows[tabs('status')] += '\n'+tsmp+fb('warn')+'*** Cannot join '+params[0]+' (you\'re banned)'+fe;
                    }
                    if (chans.indexOf(params[0]) != -1) {
                        chans.splice(chans.indexOf(params[0]),1);
                        sconf.data.chans = chans;
                        sconf.flush();
                        if (tabs(params[0]) != null) {
                            btns[tabs(params[0])].parent.removeChild(btns[tabs(params[0])]);
                            tabso[params[0].toLowerCase()] = null;
                        }
                        if (active == params[0].toLowerCase()) {
                            tabswitch('status');
                        }
                    }
                    break;
                case '475':
                    KeyPanel.show('Channel key required for '+params[0],params[0],this,chankey,channokey);
                    break;
                case '324':
                    modes[tabs(params[0])] = params.slice(1).join(' ');
                    titleupdate();
                    break;
                case '329':
                    windows[tabs(params[0])] += '\n'+tsmp+fb('info')+'*** Channel '+params[0]+' created on '+(new Date(params[1]*1000).toLocaleString())+fe;
                    break;
                case '331':
                    topics[tabs(params[0])] = '';
                    windows[tabs(params[0])] += '\n'+tsmp+fb('info')+'*** '+urlcheck(cc(trailing))+fe;
                    break;
                case '332':
                    topics[tabs(params[0])] = cc(trailing);
                    windows[tabs(params[0])] += '\n'+tsmp+fb('info')+'*** Topic for '+params[0]+' is: '+urlcheck(cc(trailing))+fe;
                    break;
                case '333':
                    windows[tabs(params[0])] += '\n'+tsmp+fb('info')+'*** Topic set by '+cc(params[1])+' at '+(new Date(params[2]*1000).toLocaleString())+fe;
                    break;
                case '352':
                    var winfo:String = '\n'+tsmp+fb('notice')+'*** ['+params[0]+'] '+fe+params[4]+fb('notice')+cc('!'+params[1]+'@'+params[2]+' ('+trailing.slice(trailing.indexOf(' ')+1))+') using '+params[3]+' (hopcount: '+trailing.slice(0,trailing.indexOf(' '))+')';
                    for (var wptr:int = 0; wptr<params[5].length; wptr++) {
                        if (params[5].charAt(wptr) == 'H') {
                            winfo += ' ('+fe+fb('info2')+'online'+fe+fb('notice')+')';
                        }
                        if (params[5].charAt(wptr) == 'G') {
                            winfo += ' (away)';
                        }
                        if (params[5].charAt(wptr) == '*') {
                            winfo += ' ('+fe+fb('warn')+'oper'+fe+fb('notice')+')';
                        }
                        for (var nptr:int = 0; nptr<npf.length; nptr++) {
                            if (params[5].charAt(wptr) == npf.charAt(nptr)) {
                                winfo += ' ('+params[5].charAt(wptr)+')';
                            }
                        }
                    }
                    winfo += fe;
                    windows[tabs(active)] += winfo;
                    if (active != 'status') {
                        windows[tabs('status')] += winfo;
                    }
                    break;
                case '353':
                    tusers[tabs(params[1])] += ' '+trailing;
                    break;
                case '366':
                    if (tusers[tabs(params[0])] == null) {
                        break;
                    }
                    var tua:Array = tusers[tabs(params[0])].split(/ /);
                    tua2 = new Array();
                    users[tabs(params[0])] = new Array();
                    for each(tu in tua) {
                        if (tu != '') {
                            tua2.push(tu);
                        }
                    }
                    tua2.sort(Array.CASEINSENSITIVE);
                    for (i = 0; i < npf.length; i++) {
                        for each(tu in tua2) {
                            if (tu.indexOf(npf.charAt(i)) == 0) {
                                users[tabs(params[0])].push(tu);
                            }
                        }
                    }
                    for each(tu in tua2) {
                        tb = true;
                        for (i = 0; i < npf.length; i++) {
                            if (tu.indexOf(npf.charAt(i)) == 0) {
                                tb = false;
                            }
                        }
                        if (tb) {
                            users[tabs(params[0])].push(tu);
                        }
                    }
                    tusers[tabs(params[0])] = '';
                    uupdate = true;
                    break;
                case '376':
                case '422':
                    titleupdate();
                    if ((serv.indexOf('proxy') == -1) && (Security.sandboxType != Security.LOCAL_TRUSTED)) {
                        swrite('MODE '+mynick+' +w');
                        if (loaderInfo.parameters['channels'] != null) {
                            swrite('JOIN '+loaderInfo.parameters['channels']);
                        } else if ((String)(config.channels.@autojoin).length > 0) {
                            swrite('JOIN '+config.channels.@autojoin);
                        }
                        for each(var c:String in chans) {
                            if ((String)(config.channels.@autojoin).indexOf(c) == -1) {
                                swrite('JOIN '+c);
                            }
                        }
                    }
                    break;
                case '432':
                case '433':
                    NickPanel.show(trailing,this,renick);
                    break;
                case '465':
                    windows[tabs(active)] += '\n'+tsmp+fb('warn')+'*** You are k-lined ('+urlcheck(cc(trailing))+')'+fe;
                    if (active != 'status') {
                        windows[tabs('status')] += '\n'+tsmp+fb('warn')+'*** You are k-lined ('+urlcheck(cc(trailing))+')'+fe;
                    }
                    break;
                case '006':
                case '007':
                case '290':
                case '292':
                case '305':
                case '306':
                case '315':
                case '318':
                case '347':
                case '349':
                case '368':
                case '369':
                case '381':
                case '409':
                case '411':
                case '412':
                case '439':
                case '445':
                case '446':
                case '451':
                case '462':
                case '463':
                case '464':
                case '465':
                case '481':
                case '483':
                case '484':
                case '485':
                case '491':
                case '501':
                case '502':
                case '505':
                case '513':
                case '705':
                case '706':
                case '901':
                case '902':
                    windows[tabs(active)] += '\n'+tsmp+fb('notice')+'*** '+urlcheck(cc(trailing))+fe;
                    if (active != 'status') {
                        windows[tabs('status')] += '\n'+tsmp+fb('notice')+'*** '+urlcheck(cc(trailing))+fe;
                    }
                    break;
                default:
                    if (config.core.@debug == 'true') {
                        windows[tabs('unhandled')] += '\n'+tsmp+tline;
                    }
            }
        }
    }
    refresh();
}

internal function closetab2(closesrc:String):void {
    btns[tabs(closesrc)].parent.removeChild(btns[tabs(closesrc)]);
    tabso[closesrc.toLowerCase()] = null;
    if (closesrc.toLowerCase() == active.toLowerCase()) {
        tabswitch('status');
    }
}

internal function chanlistupdate(updatesrc:String,b:SideButton):void {
    swrite('LIST');
}

internal function closetab(closesrc:String,cb:SideButton):void {
    if (achans.indexOf(closesrc.toLowerCase()) == -1) {
        if (glows[tabs(closesrc)] != null) {
            glows[tabs(closesrc)].end();
            glows[tabs(closesrc)] = null;
        }
        var tatimer:int = getTimer();
        if ((tatimer-lastadd) > 300) {
            lastadd = tatimer;
            setTimeout(closetab2,20,closesrc);
        } else {
            setTimeout(closetab2,300-(tatimer-lastadd)+20,closesrc);
            lastadd = tatimer+300-(tatimer-lastadd);
        }
    } else {
        swrite('PART '+closesrc);
    }
    cb.removeEventListener('change',btnchange);
}

internal function invjoin(c:String):void {
    swrite('JOIN '+c);
}

internal function chankey(c:String,k:String):void {
    swrite('JOIN '+c+' :'+k);
}

internal function channokey(c:String):void {
    if (chans.indexOf(c) != -1) {
        chans.splice(chans.indexOf(c),1);
        sconf.data.chans = chans;
        sconf.flush();
        if (tabs(c) != null) {
            btns[tabs(c)].parent.removeChild(btns[tabs(c)]);
            tabso[c.toLowerCase()] = null;
        }
        if (active == c.toLowerCase()) {
            tabswitch('status');
        }
    }
}

internal function clearcmdline():void {
    cmdline.text = '';
}

internal function newline():void {
    var ct:String = cmdline.text.replace(/\u000B/g,'\u0003');
    cmdpos = 0;
    if (ct == '') {
        return;
    }
    cmdh[tabs(active)].push(ct);
    setTimeout(clearcmdline,20);
    var cts:Array = ct.split(' ');
    var ctc:String = cts[0].toLowerCase();
    var ctsi:int = ct.indexOf(' ');
    var ctsi2:int;
    if (ctsi == -1) {
        ctsi = ct.length;
        ctsi2 = ct.length;
    } else {
        ctsi2 = ct.indexOf(' ',ctsi+1)+1;
        if (ctsi2 == -1) {
            ctsi2 = ct.length;
        }
    }
    var td:Date = new Date();
    var tdh:String = td.getHours().toString();
    var tdm:String = td.getMinutes().toString();
    var tds:String = td.getSeconds().toString();
    if (tdh.length == 1) {
        tdh = '0'+tdh;
    }
    if (tdm.length == 1) {
        tdm = '0'+tdm;
    }
    if (tds.length == 1) {
        tds = '0'+tds;
    }
    var tsmp:String = fb('time')+'['+tdh+':'+tdm+':'+tds+'] '+fe;
    var scmd:String;
    var fcmd:String;
    for each(var c:XML in commands..@name) {
        if (ctc == '/'+c) {
            var tcmd:String = commands.cmd.(@name == c).@code;
            var tnick:String = '';
            var thost:String = '';
            if ((tcmd.indexOf('$nick') != -1) || (tcmd.indexOf('$host') != -1)) {
                if (cts[1] != null) {
                    tnick = cts[1];
                    if (tcmd.indexOf('$host') != -1) {
                        if (cts[1].indexOf('@') == -1) {
                            thost = cts[1]+'!*@*';
                        } else {
                            thost = cts[1];
                        }
                    }
                } else {
                    fcmd = c;
                    break;
                }
            }
            scmd = tcmd;
            while (scmd.indexOf('$') != -1) {
                scmd = scmd.replace('$active',active).replace('$mynick',mynick).replace('$nick',tnick).replace('$host',thost).replace('$reason',ct.slice(ctsi2));
            }
        }
    }
    if ((active == 'debug') || (active == 'unhandled')) {
        swrite(ct);
    } else if ((active == 'status') && ((ct.indexOf('/') != 0) || (ctc == '/me'))) {
        return;
    } else {
        if (fcmd != null) {
            windows[tabs(active)] += '\n'+tsmp+fb('notice')+'*** '+fcmd.toUpperCase()+': Not enough parameters';
        } else if (scmd != null) {
            var scmda:Array = scmd.split('\\n');
            var scmdd:int = 0;
            for each(var tscmd:String in scmda) {
                setTimeout(swrite,scmdd,tscmd);
                scmdd += 1000;
            }
        } else if (ctc == '/j') {
            var tch:String = ct.slice(ctsi+1);
            var tcha:Array = tch.split(',');
            var tcha2:Array = new Array();
            var tchb:Boolean;
            for each(tch in tcha) {
                tchb = false;
                for (var ti:int=0; ti<cpf.length; ti++) {
                    if (tch.charAt(0) == cpf.charAt(ti)) {
                        tchb = true;
                    }
                }
                if (!tchb) {
                    tch = cpf.charAt(0)+tch;
                }
                tcha2.push(tch);
            }
            swrite('JOIN '+tcha2.join(','));
        } else if (ct.toLowerCase() == '/part') {
            swrite('PART '+active);
        } else if (ct.toLowerCase() == '/clear') {
            windows[tabs(active)] = '\n'+tsmp+fb('notice')+'*** Window cleared'+fe;
        } else if (ctc == '/win') {
            if (cts[1] != null) {
                if (tabs(cts[1]) == null) {
                    windows[tabs(active)] += '\n'+tsmp+fb('notice')+'*** No such window'+fe;
                } else {
                    tabswitch(cts[1]);
                }
            }
        } else if (ctc == '/away') {
            swrite('AWAY :'+ct.slice(ctsi+1));
        } else if (ct.toLowerCase() == '/back') {
            swrite('AWAY :');
        } else if (ctc == '/query') {
            if (cts[1] != null) {
                if (tabs(cts[1]) == null) {
                    addqtab(cts[1]);
                    topics[tabs(cts[1])] = cts[1];
                }
                tabswitch(cts[1]);
            }
        } else if ((ctc == '/m') || (ctc == '/msg')) {
            if (cts[1] != null) {
                swrite('PRIVMSG '+cts[1]+' :'+ct.slice(ctsi2));
                if (tabs(cts[1]) == null) {
                    windows[tabs(active)] += '\n'+tsmp+fb('mode')+'&gt;'+fe+fb('own')+cts[1]+fe+fb('mode')+'&lt; '+fe+fb('own')+cc(ct.slice(ctsi2).replace(/</g,'&lt;').replace(/>/g,'&gt;'))+fe;
                } else {
                    windows[tabs(cts[1])] += '\n'+tsmp+fb('mode')+'&lt;'+fe+fb('own')+mynick+fe+fb('mode')+'&gt; '+fe+fb('own')+cc(ct.slice(ctsi2).replace(/</g,'&lt;').replace(/>/g,'&gt;'))+fe;
                }
            }
        } else if (ctc == '/notice') {
            if (cts[1] != null) {
                swrite('NOTICE '+cts[1]+' :'+ct.slice(ctsi2));
                windows[tabs(active)] += '\n'+tsmp+fb('mode')+'&gt;&gt;'+fe+fb('own')+cts[1]+fe+fb('mode')+'&lt;&lt; '+fe+fb('own')+cc(ct.slice(ctsi2).replace(/</g,'&lt;').replace(/>/g,'&gt;'))+fe;
            }
        } else if (ctc == '/skin') {
            if (cts[1] != null) {
                if (stylemanager.getStyleDeclaration('tiramisu') != null) {
                    stylemanager.unloadStyleDeclarations('skins/'+cskin+'.swf');
                }
                cskin = cts[1];
                stylemanager.loadStyleDeclarations('skins/'+cskin+'.swf').addEventListener(StyleEvent.COMPLETE,etitleupdate);
            }
        } else if ((ctc == '/quit') || (ctc == '/exit')) {
            swrite('QUIT :'+ct.slice(ctsi+1));
        } else if (ctc == '/topic') {
            if (ct.length == 6) {
                swrite('TOPIC '+active);
            } else {
                swrite('TOPIC '+active+' :'+ct.slice(ctsi+1));
            }
        } else if (ctc == '/umode') {
            if (cts[1] != null) {
                swrite('MODE '+mynick+' '+cts[1]);
            }
        } else if (ctc == '/wii') {
            if (cts[1] != null) {
                swrite('WHOIS '+cts[1]+' '+cts[1]);
            }
        } else if (ctc == '/whois') {
            if (cts[1] != null) {
                swrite('WHOIS '+cts[1]);
            }
        } else if (ctc == '/invite') {
            if (cts[1] != null) {
                swrite('INVITE '+cts[1]+' '+active);
            }
        } else if (ctc == '/ballson') {
            ul.balls = true;
            uupdate = true;
        } else if (ctc == '/ballsoff') {
            ul.balls = false;
            uupdate = true;
        } else if (ctc == '/encoding') {
            if (cts[1] != null) {
                config.server.@encoding = cts[1];
                windows[tabs(active)] += '\n'+tsmp+fb('notice')+'*** Encoding changed to '+cts[1].replace(/</g,'&lt;').replace(/>/g,'&gt;')+fe;
            }
        } else if ((ctc == '/quote') || (ctc == '/raw')) {
            swrite(ct.slice(ctsi+1));
        } else if (ctc == '/ctcp') {
            if (cts[1] != null) {
                swrite('PRIVMSG '+cts[1]+' :\u0001'+cts[2].toUpperCase()+'\u0001');
                windows[tabs(active)] += '\n'+tsmp+fb('notice')+'*** Sending CTCP '+cts[2].toLowerCase().replace(/</g,'&lt;').replace(/>/g,'&gt;')+' to '+fe+cts[1];
                if (cts[2].toUpperCase() == 'PING') {
                    lastping = getTimer();
                }
            }
        } else if (ctc == '/me') {
            swrite('PRIVMSG '+active+' :\u0001ACTION'+ct.slice(3)+'\u0001');
            windows[tabs(active)] += '\n'+tsmp+fb('own')+'* '+mynick+cc(ct.slice(3).replace(/</g,'&lt;').replace(/>/g,'&gt;'))+fe;
        } else if (ct.indexOf('/') == 0) {
            swrite(ctc.slice(1).toUpperCase()+ct.slice(ctsi));
        } else if (ct.indexOf(' ') == 0) {
            swrite('PRIVMSG '+active+' :'+ct.slice(1));
            windows[tabs(active)] += '\n'+tsmp+fb('mode')+'&lt;'+fe+fb('own')+mynick+fe+fb('mode')+'&gt; '+fe+fb('own')+cc(ct.slice(1).replace(/</g,'&lt;').replace(/>/g,'&gt;'))+fe;
        } else {
            swrite('PRIVMSG '+active+' :'+ct);
            windows[tabs(active)] += '\n'+tsmp+fb('mode')+'&lt;'+fe+fb('own')+mynick+fe+fb('mode')+'&gt; '+fe+fb('own')+urlcheck(cc(ct.replace(/</g,'&lt;').replace(/>/g,'&gt;')))+fe;
        }
    }
    refresh();
}

internal function newtopic():void {
    swrite('TOPIC '+active+' :'+topic.text);
}

internal function userdclick():void {
    if (ul.selectedIndex == -1) {
        return;
    }
    var su:String = users[tabs(active)][ul.selectedIndex];
    for (var i:int = 0; i < npf.length; i++) {
        if (su.indexOf(npf.charAt(i)) == 0) {
            su = su.slice(1);
            break;
        }
    }
    if (tabs(su) == null) {
        addqtab(su);
        topics[tabs(su)] = su;
    }
    tabswitch(su);
}

internal function refresh():void {
    if (windows[tabs(active)] == null) {
        return;
    }
    var bls:Array = windows[tabs(active)].split('\n');
    while (bls.length > backlog) {
        bls.shift();
    }
    windows[tabs(active)] = bls.join('\n');
    ca.htmlText = windows[tabs(active)];
    if (focusManager.getFocus() != topic) {
        topic.htmlText = urlcheck(topics[tabs(active)]);
        topic.editable = false;
        for (var i:int = 0; i < cpf.length; i++) {
            if (active.indexOf(cpf.charAt(i)) == 0) {
                if ((users[tabs(active)].indexOf('~'+mynick) != -1) || (users[tabs(active)].indexOf('&'+mynick) != -1) || (users[tabs(active)].indexOf('@'+mynick) != -1) || (users[tabs(active)].indexOf('%'+mynick) != -1)) {
                    topic.editable = true;
                }
                if (modes[tabs(active)].split(' ')[0].indexOf('t') == -1) {
                    topic.editable = true;
                }
            }
        }
    }
    if (users[tabs(active)].length > 0) {
        if (users[tabs(active)].length == 1) {
            ulcount.text = '1 member';
        } else {
            ulcount.text = users[tabs(active)].length+' members';
        }
        currentState = 'channel';
        if (uupdate) {
            ul.dataProvider = users[tabs(active)];
            uupdate = false;
        }
    } else if ((active == 'debug') || (active == 'unhandled') || (active == 'status')) {
        currentState = '';
    } else if (active == 'chanlist') {
        currentState = 'list';
    } else {
        currentState = 'query';
    }
}

internal function sioerr(e:IOErrorEvent):void {
    serv = 'status';
    titleupdate();
    reconnwait = true;
    InfoPanel.show('Connection reset',e.text,this,'Reconnect',reconn);
}

internal function sclosed(e:Event):void {
    serv = 'status';
    titleupdate();
    reconnwait = true;
    InfoPanel.show('Connection closed',scmsg,this,'Reconnect',reconn);
    scmsg = 'Server closed the connection.';
}

internal function secerr(e:SecurityErrorEvent):void {
    if (!reconnwait) {
        InfoPanel.show('Security error',e.text,this);
    }
}

internal function addstab(tname:String):void {
    var idx:uint = uniqueidx;
    uniqueidx++;
    btns[idx] = new SideButton();
    btns[idx].label = tname;
    btns[idx].addEventListener('change',btnchange);
    var tatimer:int = getTimer();
    if ((tatimer-lastadd) > 300) {
        lastadd = tatimer;
        sbar.addChild(btns[idx]);
        setTimeout(btnbarvalidate,20);
    } else {
        setTimeout(sbar.addChild,300-(tatimer-lastadd),btns[idx]);
        setTimeout(btnbarvalidate,300-(tatimer-lastadd)+20);
        lastadd = tatimer+300-(tatimer-lastadd);
    }
    users[idx] = new Array();
    tusers[idx] = '';
    tstamps[idx] = new Object();
    cmdh[idx] = new Array();
    windows[idx] = '';
    topics[idx] = '';
    modes[idx] = '';
    mmodes[idx] = new Object();
    tabso[tname.toLowerCase()] = idx;
    uupdate = true;
}

internal function addctab(tname:String):void {
    var idx:uint = uniqueidx;
    uniqueidx++;
    btns[idx] = new SideButton();
    btns[idx].label = tname;
    btns[idx].addEventListener('change',btnchange);
    btns[idx].closebtninit(closetab);
    var tatimer:int = getTimer();
    if ((tatimer-lastadd) > 300) {
        lastadd = tatimer;
        cbar.addChild(btns[idx]);
        setTimeout(btnbarvalidate,20);
    } else {
        setTimeout(cbar.addChild,300-(tatimer-lastadd),btns[idx]);
        setTimeout(btnbarvalidate,300-(tatimer-lastadd)+20);
        lastadd = tatimer+300-(tatimer-lastadd);
    }
    users[idx] = new Array();
    tusers[idx] = '';
    tstamps[idx] = new Object();
    cmdh[idx] = new Array();
    windows[idx] = '';
    topics[idx] = '';
    modes[idx] = '';
    mmodes[idx] = new Object();
    tabso[tname.toLowerCase()] = idx;
    uupdate = true;
}

internal function addqtab(tname:String):void {
    var idx:uint = uniqueidx;
    uniqueidx++;
    btns[idx] = new SideButton();
    btns[idx].label = tname;
    btns[idx].addEventListener('change',btnchange);
    btns[idx].closebtninit(closetab);
    var tatimer:int = getTimer();
    if ((tatimer-lastadd) > 300) {
        lastadd = tatimer;
        qbar.addChild(btns[idx]);
        setTimeout(btnbarvalidate,20);
    } else {
        setTimeout(qbar.addChild,300-(tatimer-lastadd),btns[idx]);
        setTimeout(btnbarvalidate,300-(tatimer-lastadd)+20);
        lastadd = tatimer+300-(tatimer-lastadd);
    }
    users[idx] = new Array();
    tusers[idx] = '';
    tstamps[idx] = new Object();
    cmdh[idx] = new Array();
    windows[idx] = '';
    topics[idx] = '';
    modes[idx] = '';
    mmodes[idx] = new Object();
    tabso[tname.toLowerCase()] = idx;
    uupdate = true;
}

internal function rentab(t1:String,t2:String):void {
    btns[tabs(t1)].label = t2;
    tabso[t2.toLowerCase()] = tabs(t1);
    if (active == t1.toLowerCase()) {
        active = t2.toLowerCase();
    }
    setTimeout(btnbarvalidate,20);
}

internal function btnchange(e:Event):void {
    if (inchange) {
        return;
    }
    inchange = true;
    if (e.target.selected == false) {
        e.target.selected = true;
    } else {
        for each(var tmpb:SideButton in btns) {
            if (tmpb != e.target) {
                tmpb.selected = false;
            }
        }
    }
    active = e.target.label.toLowerCase();
    if (glows[tabs(active)] != null) {
        glows[tabs(active)].end();
        glows[tabs(active)] = null;
    }
    if (active == 'chanlist') {
        swrite('LIST');
    }
    titleupdate();
    inchange = false;
    uupdate = true;
    refresh();
}

internal function tabswitch(bs:String):void {
    var tbtn:SideButton = btns[tabs(bs)];
    if (tbtn.selected == false) {
        tbtn.selected = true;
    }
    for each(var tmpb:SideButton in btns) {
        if (tmpb != tbtn) {
            tmpb.selected = false;
        }
    }
    active = tbtn.label.toLowerCase();
    if (glows[tabs(active)] != null) {
        glows[tabs(active)].end();
        glows[tabs(active)] = null;
    }
    titleupdate();
    uupdate = true;
    refresh();
}

internal function etitleupdate(e:Event):void {
    titleupdate();
}

internal function titleupdate():void {
    var release:String;
    var ptitle:String;
    var tssl:String = '';
    if (config != null) {
        if (config.server.@ssl == 'true') {
            tssl = ' [SSL]';
        }
    }
    release = 'tiramisu '+version;
    if (serv == 'status') {
        ptitle = release;
    } else {
        ptitle = release+' | '+mynick+'@'+serv+tssl+' ['+umode+']';
        if (achans.indexOf(active) != -1) {
            for (var i:int = 0; i < cpf.length; i++) {
                if (active.indexOf(cpf.charAt(i)) == 0) {
                    ptitle = release+' | '+mynick+'@'+serv+tssl+' ['+umode+'] | '+active+' ['+modes[tabs(active)]+']';
                }
            }
        }
    }
    if ((ptitle.length*9) > panel.width) {
        ptitle = ptitle.substr(0,panel.width/9)+'...';
    }
    panel.title = ptitle;
}

internal function cfgerror(e:IOErrorEvent):void {
    InfoPanel.show('Config file not loaded',e.text,this);
}

internal function getcsscolor(comp:String,field:String,selector:int=-1):String {
    if (stylemanager.getStyleDeclaration(comp) == null) {
        return '#000000';
    }
    if (stylemanager.getStyleDeclaration(comp).getStyle(field) == null) {
        return '#000000';
    }
    var c:String;
    if (selector == -1) {
        c = stylemanager.getStyleDeclaration(comp).getStyle(field).toString(16);
    } else {
        c = stylemanager.getStyleDeclaration(comp).getStyle(field)[selector].toString(16);
    }
    while (c.length < 6) {
        c = '0'+c;
    }
    c = '#'+c.toUpperCase();
    return c;
}

internal function centerfix(uic:UIComponent):void {
    uic.transform.perspectiveProjection.projectionCenter = new Point(uic.x+uic.width/2,uic.y+uic.height/2);
}

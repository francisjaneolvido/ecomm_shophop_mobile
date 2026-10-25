import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shophop/core/session/auth_session_service.dart';
import 'package:shophop/features/auth/data/services/auth_service.dart';
import 'package:shophop/features/auth/presentation/screens/login_screen.dart';
import 'package:shophop/features/linehaul/data/linehaul_service.dart';

class LinehaulDriverHomeScreen extends StatefulWidget {
  const LinehaulDriverHomeScreen({super.key});
  @override
  State<LinehaulDriverHomeScreen> createState() => _LinehaulDriverHomeScreenState();
}

class _LinehaulDriverHomeScreenState extends State<LinehaulDriverHomeScreen> {
  static const _navy = Color(0xFF0E1B4D);
  static const _teal = Color(0xFF18AA94);
  final _camera = MobileScannerController(autoStart: false);
  List<Map<String,dynamic>> _trips=[];
  Map<String,dynamic>? _manifest;
  String? _token, _email, _message;
  bool _success=false, _busy=true, _scanning=false;
  int _tab=0;

  @override void initState(){super.initState();_load();}
  @override void dispose(){_camera.dispose();super.dispose();}
  List<Map<String,dynamic>> _rows(dynamic v)=>v is List?v.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList():[];

  Future<void> _load() async {
    final session=await AuthSessionService.readSession();
    if(!mounted)return;
    if(session==null||session.accountType!='linehaul_driver'){await _logout(localOnly:true);return;}
    setState((){_token=session.token;_email=session.email;_busy=true;});
    final r=await LinehaulService.trips(session.token);
    if(!mounted)return;
    if(r.statusCode==401||r.statusCode==403){await _logout(localOnly:true);return;}
    setState((){_busy=false;if(r.success)_trips=_rows(r.data['trips']);_message=r.success?null:r.message;_success=false;});
  }

  Future<void> _logout({bool localOnly=false}) async {
    try{await _camera.stop();}catch(_){}
    if(!localOnly&&_token!=null) await AuthService.logout(token:_token!);
    await AuthSessionService.clearSession();
    if(!mounted)return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder:(_)=>const LoginScreen()),(_)=>false);
  }

  Future<void> _startScan() async {
    if(_busy)return;
    setState((){_scanning=true;_manifest=null;_message=null;});
    try{await _camera.start();}catch(_){if(mounted)setState((){_scanning=false;_message='Camera unavailable. Grant camera permission and try again.';});}
  }

  Future<void> _scan(String code) async {
    if(_busy||_token==null||code.trim().isEmpty)return;
    setState((){_busy=true;_scanning=false;_manifest=null;_message=null;});
    try{await _camera.stop();}catch(_){}
    final r=await LinehaulService.preview(token:_token!,manifestCode:code);
    if(!mounted)return;
    setState((){_busy=false;_manifest=r.success&&r.data['manifest'] is Map?Map<String,dynamic>.from(r.data['manifest'] as Map):null;_message=r.success?null:r.message;_success=false;});
  }

  Future<void> _confirm() async {
    final m=_manifest;if(m==null||_token==null||_busy)return;
    final action=m['action']?.toString()??'none';if(action!='depart'&&action!='arrive')return;
    final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:Text(action=='depart'?'Accept load & depart?':'Confirm arrival?'),content:Text(action=='depart'?'Confirm only after manifest ${m['manifest_code']} is physically loaded in ${m['vehicle_code']} (${m['plate_number']}).':'Confirm only after the vehicle physically arrives at ${m['to']}.'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:Text(action=='depart'?'Accept & depart':'Mark arrived'))]));
    if(ok!=true||!mounted)return;
    setState(()=>_busy=true);
    final r=await LinehaulService.confirm(token:_token!,manifestCode:m['manifest_code'].toString(),action:action);
    if(!mounted)return;
    setState((){_busy=false;_manifest=null;_message=r.message;_success=r.success;});
    await _load();
  }

  Widget _tripCard(Map<String,dynamic> t)=>Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Row(children:[Expanded(child:Text(t['code']?.toString()??'Linehaul Trip',style:const TextStyle(fontWeight:FontWeight.w800,color:_navy))),Chip(label:Text((t['status']??'').toString().replaceAll('_',' ').toUpperCase()))]),
    Text('${t['from']??'Origin'} → ${t['to']??'Destination'}',style:const TextStyle(fontSize:15,fontWeight:FontWeight.w700)),
    const SizedBox(height:6),Text('Manifest: ${t['manifest_code']??'—'} · ${t['parcel_count']??0} parcels'),
    Text('Vehicle: ${t['vehicle_code']??'—'} · ${t['plate_number']??'—'}'),
  ])));

  Widget _tripsPage({bool history=false}){
    final rows=_trips.where((t)=>history?['completed','cancelled'].contains(t['status']):!['completed','cancelled'].contains(t['status'])).toList();
    return RefreshIndicator(onRefresh:_load,child:ListView(padding:const EdgeInsets.fromLTRB(16,18,16,100),children:[
      Text(history?'Trip History':'Linehaul Trips',style:const TextStyle(fontSize:24,fontWeight:FontWeight.w900,color:_navy)),
      const SizedBox(height:4),Text(history?'Completed fleet movements.':'Your assigned manifest movements. Driver scans the manifest QR, not every parcel.',style:const TextStyle(color:Color(0xFF65748A))),
      const SizedBox(height:16),if(rows.isEmpty)const Card(child:Padding(padding:EdgeInsets.all(20),child:Text('No trips in this section.'))),...rows.map(_tripCard)
    ]));
  }

  Widget _scanPage()=>ListView(padding:const EdgeInsets.fromLTRB(16,18,16,100),children:[
    const Text('Scan Manifest',style:TextStyle(fontSize:24,fontWeight:FontWeight.w900,color:_navy)),
    const SizedBox(height:4),const Text('Scan the Manifest QR to accept a fully loaded batch or record arrival at its destination.',style:TextStyle(color:Color(0xFF65748A))),
    const SizedBox(height:16),
    if(_message!=null)Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:_success?const Color(0xFFE8F7F1):const Color(0xFFFFF3E8),borderRadius:BorderRadius.circular(14)),child:Text(_message!)),
    if(_message!=null)const SizedBox(height:12),
    if(_scanning)ClipRRect(borderRadius:BorderRadius.circular(18),child:SizedBox(height:320,child:MobileScanner(controller:_camera,onDetect:(capture){if(_busy||!_scanning)return;for(final b in capture.barcodes){final v=b.rawValue;if(v!=null&&v.trim().isNotEmpty){_scan(v);break;}}}))),
    const SizedBox(height:12),OutlinedButton.icon(onPressed:_busy?null:(_scanning?(){_camera.stop();setState(()=>_scanning=false);}:_startScan),icon:Icon(_scanning?Icons.stop_circle_outlined:Icons.camera_alt_outlined),label:Text(_scanning?'Stop camera':'Open camera')),
    if(_manifest!=null)...[const SizedBox(height:16),Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text('${_manifest!['manifest_code']}',style:const TextStyle(fontSize:20,fontWeight:FontWeight.w900,color:_navy)),
      Text('${_manifest!['from']} → ${_manifest!['to']}',style:const TextStyle(fontWeight:FontWeight.w700)),
      const SizedBox(height:8),Text('Trip: ${_manifest!['trip_code']} · ${_manifest!['trip_status']}'),Text('Vehicle: ${_manifest!['vehicle_code']} · ${_manifest!['plate_number']}'),Text('Loaded: ${_manifest!['loaded']} / ${_manifest!['expected']} · Received: ${_manifest!['received']}'),
      const SizedBox(height:14),SizedBox(width:double.infinity,child:FilledButton(style:FilledButton.styleFrom(backgroundColor:_teal),onPressed:_busy||_manifest!['action']=='none'?null:_confirm,child:Text(_manifest!['confirm_label']?.toString()??'Confirm')))
    ])))],
  ]);

  Widget _vehiclePage(){final active=_trips.where((t)=>!['completed','cancelled'].contains(t['status'])).toList();final t=active.isEmpty?null:active.first;return ListView(padding:const EdgeInsets.fromLTRB(16,18,16,100),children:[const Text('Vehicle',style:TextStyle(fontSize:24,fontWeight:FontWeight.w900,color:_navy)),const SizedBox(height:16),Card(child:Padding(padding:const EdgeInsets.all(18),child:t==null?const Text('No active vehicle assignment.'):Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${t['vehicle_code']??'Vehicle'}',style:const TextStyle(fontSize:20,fontWeight:FontWeight.w900)),Text('${t['vehicle_type']??''} · ${t['plate_number']??'—'}'),const SizedBox(height:8),Text('Active trip: ${t['code']}'),Text('${t['from']} → ${t['to']}')])))]);}
  Widget _accountPage()=>ListView(padding:const EdgeInsets.fromLTRB(16,18,16,100),children:[const Text('Account',style:TextStyle(fontSize:24,fontWeight:FontWeight.w900,color:_navy)),const SizedBox(height:16),Card(child:ListTile(leading:const CircleAvatar(child:Icon(Icons.badge_outlined)),title:const Text('Linehaul Driver'),subtitle:Text(_email??''))),const SizedBox(height:12),OutlinedButton.icon(onPressed:_busy?null:()=>_logout(),icon:const Icon(Icons.logout),label:const Text('Sign out'))]);

  @override Widget build(BuildContext context){
    final pages=[_tripsPage(),_vehiclePage(),_scanPage(),_tripsPage(history:true),_accountPage()];
    return Scaffold(appBar:AppBar(title:const Text('ShopHop Linehaul',style:TextStyle(fontWeight:FontWeight.w800)),actions:[IconButton(onPressed:_busy?null:_load,icon:const Icon(Icons.refresh))]),body:_busy&&_trips.isEmpty?const Center(child:CircularProgressIndicator()):pages[_tab],bottomNavigationBar:NavigationBar(selectedIndex:_tab,onDestinationSelected:(i){if(_scanning&&i!=2){_camera.stop();_scanning=false;}setState(()=>_tab=i);},destinations:const[
      NavigationDestination(icon:Icon(Icons.route_outlined),selectedIcon:Icon(Icons.route),label:'Trips'),
      NavigationDestination(icon:Icon(Icons.local_shipping_outlined),selectedIcon:Icon(Icons.local_shipping),label:'Vehicle'),
      NavigationDestination(icon:Icon(Icons.camera_alt_outlined),selectedIcon:Icon(Icons.camera_alt),label:'Scan'),
      NavigationDestination(icon:Icon(Icons.history_outlined),selectedIcon:Icon(Icons.history),label:'History'),
      NavigationDestination(icon:Icon(Icons.person_outline),selectedIcon:Icon(Icons.person),label:'Account'),
    ]));
  }
}

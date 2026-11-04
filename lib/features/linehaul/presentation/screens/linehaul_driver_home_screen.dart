import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shophop/core/theme/app_colors.dart';
import 'package:shophop/shared/widgets/shop_hop_navigation.dart';
import 'package:shophop/shared/widgets/shop_hop_ui.dart';
import 'package:shophop/shared/widgets/shop_hop_workflow.dart';
import 'package:shophop/shared/widgets/shop_hop_ops.dart';
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
  static const _navy = AppColors.navy;
  static const _teal = AppColors.tealDark;
  final _camera = MobileScannerController(autoStart: false);
  final _manifestCode = TextEditingController();
  List<Map<String,dynamic>> _trips=[];
  List<Map<String,dynamic>> _earnings=[];
  double _pendingEarnings=0, _availableEarnings=0, _paidEarnings=0;
  Map<String,dynamic>? _manifest;
  String? _token, _email, _message;
  bool _success=false, _busy=true, _scanning=false;
  int _tab=0;
  Timer? _refreshTimer;

  @override void initState(){
    super.initState();
    _load();
    _refreshTimer=Timer.periodic(const Duration(seconds: 10),(_){
      if(mounted&&!_busy&&!_scanning)_load(silent:true);
    });
  }
  @override void dispose(){_refreshTimer?.cancel();_manifestCode.dispose();_camera.dispose();super.dispose();}
  List<Map<String,dynamic>> _rows(dynamic v)=>v is List?v.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList():[];

  Future<void> _load({bool silent=false}) async {
    final session=await AuthSessionService.readSession();
    if(!mounted)return;
    if(session==null||session.accountType!='linehaul_driver'){await _logout(localOnly:true);return;}
    setState((){_token=session.token;_email=session.email;if(!silent)_busy=true;});
    final results=await Future.wait([LinehaulService.trips(session.token),LinehaulService.earnings(session.token)]);
    if(!mounted)return;
    final r=results[0], e=results[1];
    if(r.statusCode==401||r.statusCode==403||e.statusCode==401||e.statusCode==403){await _logout(localOnly:true);return;}
    setState((){
      _busy=false;
      if(r.success)_trips=_rows(r.data['trips']);
      if(e.success){
        _earnings=_rows(e.data['entries']);
        _pendingEarnings=(e.data['pending'] as num?)?.toDouble()??0;
        _availableEarnings=(e.data['available'] as num?)?.toDouble()??0;
        _paidEarnings=(e.data['paid'] as num?)?.toDouble()??0;
      }
      _message=r.success?(e.success?null:e.message):r.message;
      _success=false;
    });
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
    _manifestCode.text=code.trim().toUpperCase();
    setState((){_busy=true;_scanning=false;_manifest=null;_message=null;});
    try{await _camera.stop();}catch(_){}
    final r=await LinehaulService.preview(token:_token!,manifestCode:code);
    if(!mounted)return;
    setState((){_busy=false;_manifest=r.success&&r.data['manifest'] is Map?Map<String,dynamic>.from(r.data['manifest'] as Map):null;_message=r.success?null:r.message;_success=false;});
  }

  Future<void> _confirm() async {
    final m=_manifest;if(m==null||_token==null||_busy)return;
    final action=m['action']?.toString()??'none';if(action!='depart')return;
    final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(
      title:const Text('Accept load & depart?'),
      content:Text('Confirm only after manifest ${m['manifest_code']} is physically loaded in ${m['vehicle_code']} (${m['plate_number']}). The destination Branch/Hub will confirm arrival by scanning this Manifest QR.'),
      actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Accept & depart'))]));
    if(ok!=true||!mounted)return;
    setState(()=>_busy=true);
    final r=await LinehaulService.confirm(token:_token!,manifestCode:m['manifest_code'].toString(),action:'depart');
    if(!mounted)return;
    setState((){_busy=false;_manifest=null;_message=r.message;_success=r.success;});
    await _load();
  }

  Widget _tripCard(Map<String, dynamic> trip, {bool featured = false}) {
    final status = (trip['status'] ?? 'assigned').toString();
    final flagged = trip['requires_review'] == true;
    final active = !['completed', 'cancelled'].contains(status);
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: ShopHopSurface(padding: const EdgeInsets.all(13), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.local_shipping_outlined, color: _teal, size: 20),
            const SizedBox(width: 9),
            Expanded(child: Text('${trip['code'] ?? 'Linehaul trip'}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
                color: _navy), maxLines: 1, overflow: TextOverflow.ellipsis)),
            ShopHopStatusPill(label: status.replaceAll('_', ' ')),
          ]),
          const SizedBox(height: 9),
          Text('${trip['from'] ?? 'Origin'} → ${trip['to'] ?? 'Destination'}',
            style: const TextStyle(color: _navy, fontSize: 13,
              fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('Manifest ${trip['manifest_code'] ?? '—'} · '
            '${trip['parcel_count'] ?? 0} parcels',
            style: const TextStyle(fontSize: 11, color: Color(0xFF607084))),
          if (featured) ...[
            const SizedBox(height: 4),
            Text('Vehicle ${trip['vehicle_code'] ?? '—'} · '
              '${trip['plate_number'] ?? '—'}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF607084))),
          ],
          if (flagged) ...[
            const SizedBox(height: 10),
            Container(width: double.infinity, padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFFFF3E8),
                borderRadius: BorderRadius.circular(6)),
              child: Text('${trip['route_warning'] ?? 'Route needs Logistics review.'}',
                style: const TextStyle(color: Color(0xFF8C5100), fontSize: 11))),
          ],
          if (active && !flagged) ...[
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, child: OutlinedButton.icon(
              onPressed: _busy ? null : () => setState(() {
                _tab = 1;
                _manifestCode.text = (trip['manifest_code'] ?? '').toString();
              }),
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('Review / scan manifest'))),
          ],
        ])),
    );
  }

  Widget _tripsPage({bool history = false}) {
    final rows = _trips.where((trip) => history
      ? ['completed', 'cancelled'].contains(trip['status'])
      : !['completed', 'cancelled'].contains(trip['status'])).toList();
    return RefreshIndicator(onRefresh: _load, child: ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 90), children: [
        ShopHopWorkflowHeader(
          title: history ? 'Trip history' : 'My assigned trips',
          subtitle: history ? 'Completed and cancelled manifests.'
            : 'Check the vehicle and route, then scan before departure.',
          icon: Icons.route_rounded,
          badge: '${rows.length} ${history ? 'past' : 'active'} trips'),
        const SizedBox(height: 12),
        if (!history && rows.isNotEmpty) ...[
          Row(children: [
            Expanded(child: ShopHopOpsCount(label: 'Assigned trips',
              value: '${rows.length}', icon: Icons.route_outlined)),
            const SizedBox(width: 8),
            Expanded(child: ShopHopOpsCount(label: 'Awaiting review',
              value: '${rows.where((t) => t['requires_review'] == true).length}',
              icon: Icons.rule_outlined)),
          ]),
          const SizedBox(height: 14),
          const ShopHopOpsHeading(title: 'Next trip',
            subtitle: 'Manifest acceptance requires physical load verification.'),
          const SizedBox(height: 8),
          _tripCard(rows.first, featured: true),
          if (rows.length > 1) ...[
            const SizedBox(height: 10),
            const ShopHopOpsHeading(title: 'Other assigned trips'),
            const SizedBox(height: 8),
          ],
          for (final trip in rows.skip(1)) _tripCard(trip),
        ] else if (rows.isNotEmpty)
          for (final trip in rows) _tripCard(trip)
        else
          const ShopHopEmptyState(icon: Icons.route_outlined,
            title: 'No trips to show',
            description: 'Dispatch assignments appear here after Logistics creates a trip.'),
      ],
    ));
  }

  Widget _scanPage() => ListView(padding: const EdgeInsets.fromLTRB(14, 12, 14, 90), children: [
    const ShopHopWorkflowHeader(title: 'Scan manifest',
      subtitle: '1. Scan or enter Manifest QR → 2. Review the load → 3. Confirm physical custody.',
      icon: Icons.qr_code_scanner_rounded),
    const SizedBox(height: 12),
    if (_message != null) ...[
      ShopHopSurface(background: _success ? const Color(0xFFE8F7F1) : const Color(0xFFFFF3E8),
        child: Text(_message!, style: const TextStyle(fontSize: 12))),
      const SizedBox(height: 10),
    ],
    ShopHopSurface(padding: const EdgeInsets.all(14), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('1  Scan manifest QR', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: _navy)),
        const SizedBox(height: 5),
        const Text('Driver scans the Manifest QR, not individual parcel labels.',
          style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        const SizedBox(height: 12),
        if (_scanning) ...[
          ClipRRect(borderRadius: BorderRadius.circular(8), child: SizedBox(
            height: 230, child: MobileScanner(controller: _camera,
              onDetect: (capture) {
                if (_busy || !_scanning) return;
                for (final barcode in capture.barcodes) {
                  final raw = barcode.rawValue;
                  if (raw != null && raw.trim().isNotEmpty) { _scan(raw); break; }
                }
              },
            ),
          )),
          const SizedBox(height: 10),
        ],
        SizedBox(width: double.infinity, child: OutlinedButton.icon(
          onPressed: _busy ? null : (_scanning
            ? () async { await _camera.stop(); if (mounted) setState(() => _scanning = false); }
            : _startScan),
          icon: Icon(_scanning ? Icons.stop_circle_outlined : Icons.qr_code_scanner_rounded),
          label: Text(_scanning ? 'Stop camera' : 'Open QR scanner'))),
        const SizedBox(height: 13),
        TextField(controller: _manifestCode, enabled: !_busy,
          onChanged: (_) => setState(() {}),
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'Or enter Manifest code',
            prefixIcon: Icon(Icons.numbers), border: OutlineInputBorder(), isDense: true)),
        const SizedBox(height: 8),
        SizedBox(width: double.infinity, child: FilledButton(
          onPressed: _busy || _manifestCode.text.trim().isEmpty
            ? null : () => _scan(_manifestCode.text),
          child: const Text('Review manifest details'))),
      ],
    )),
    if (_manifest != null) ...[
      const SizedBox(height: 12),
      ShopHopSurface(padding: const EdgeInsets.all(14), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('2  Review load & custody',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: _navy)),
          const SizedBox(height: 10),
          Text('${_manifest!['manifest_code']}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _navy)),
          Text('${_manifest!['from']} → ${_manifest!['to']}',
            style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 7),
          if (_manifest!['requires_review'] == true)
            Container(padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFFFF3E8), borderRadius: BorderRadius.circular(8)),
              child: Text(_manifest!['route_warning']?.toString() ?? 'Road trip requires Logistics review.',
                style: const TextStyle(color: Color(0xFF8C5100), fontWeight: FontWeight.w700, fontSize: 11))),
          Text('ROAD trip ${_manifest!['trip_code']} · ${_manifest!['trip_status']}'),
          Text('Vehicle ${_manifest!['vehicle_code']} · ${_manifest!['plate_number']}'),
          Text('Loaded ${_manifest!['loaded']} / ${_manifest!['expected']} · Received ${_manifest!['received']}'),
          const Divider(height: 20),
          const Text('3  Confirm only after physical load verification.',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: FilledButton.icon(
            onPressed: _busy || _manifest!['requires_review'] == true || _manifest!['action'] != 'depart' ? null : _confirm,
            icon: const Icon(Icons.check_circle_outline),
            label: Text(_manifest!['confirm_label']?.toString() ?? 'Confirm custody'))),
        ],
      )),
    ],
  ]);

  Widget _vehiclePage(){final active=_trips.where((t)=>!['completed','cancelled'].contains(t['status'])).toList();final t=active.isEmpty?null:active.first;return ListView(padding:const EdgeInsets.fromLTRB(16,18,16,100),children:[const ShopHopWorkflowHeader(title: 'Assigned vehicle', subtitle: 'Registered transport linked to your active manifest.', icon: Icons.local_shipping_outlined),const SizedBox(height:16),Card(child:Padding(padding:const EdgeInsets.all(18),child:t==null?const Text('No active vehicle assignment.'):Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${t['vehicle_code']??'Vehicle'}',style:const TextStyle(fontSize:20,fontWeight:FontWeight.w900)),Text('${t['vehicle_type']??''} · ${t['plate_number']??'—'}'),const SizedBox(height:8),Text('Active trip: ${t['code']}'),Text('${t['from']} → ${t['to']}')])))]);}
  String _money(double value)=>'₱${value.toStringAsFixed(2)}';

  Widget _accountPage()=>RefreshIndicator(onRefresh:_load,child:ListView(padding:const EdgeInsets.fromLTRB(16,18,16,100),children:[
    const ShopHopWorkflowHeader(title: 'Account & earnings', subtitle: 'Your linehaul work and completed-trip earnings.', icon: Icons.wallet_outlined),
    const SizedBox(height:16),
    Card(child:ListTile(leading:const CircleAvatar(child:Icon(Icons.badge_outlined)),title:const Text('Linehaul Driver'),subtitle:Text(_email??''))),
    const SizedBox(height:12),
    Row(children:[
      Expanded(child:Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Pending',style:TextStyle(color:Color(0xFF65748A))),const SizedBox(height:4),Text(_money(_pendingEarnings),style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900,color:_navy))])))),
      const SizedBox(width:8),
      Expanded(child:Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Available',style:TextStyle(color:Color(0xFF65748A))),const SizedBox(height:4),Text(_money(_availableEarnings),style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900,color:_teal))])))),
      const SizedBox(width:8),
      Expanded(child:Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Paid',style:TextStyle(color:Color(0xFF65748A))),const SizedBox(height:4),Text(_money(_paidEarnings),style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900,color:_navy))])))),
    ]),
    const SizedBox(height:12),
    const Text('Trip Earnings',style:TextStyle(fontSize:18,fontWeight:FontWeight.w800,color:_navy)),
    const SizedBox(height:8),
    if(_earnings.isEmpty)const Card(child:Padding(padding:EdgeInsets.all(16),child:Text('No completed-trip earnings yet.'))),
    ..._earnings.take(20).map((e)=>Card(child:ListTile(
      leading:Icon(e['status']=='paid'?Icons.check_circle_outline:e['status']=='available'?Icons.account_balance_wallet_outlined:Icons.schedule,color:_teal),
      title:Text('${e['trip_code']??'Trip'} · ${_money((e['amount'] as num?)?.toDouble()??0)}',style:const TextStyle(fontWeight:FontWeight.w800)),
      subtitle:Text('${e['from']??'Origin'} → ${e['to']??'Destination'}\n${(e['status']??'pending').toString().toUpperCase()}${e['payment_reference']!=null?' · Ref ${e['payment_reference']}':''}'),
      isThreeLine:true,
    ))),
    const SizedBox(height:12),OutlinedButton.icon(onPressed:_busy?null:()=>_logout(),icon:const Icon(Icons.logout),label:const Text('Sign out'))
  ]));

  @override Widget build(BuildContext context){
    final pages=[_tripsPage(),_scanPage(),_vehiclePage(),_tripsPage(history:true),_accountPage()];
    return Scaffold(appBar:AppBar(title:const Text('ShopHop Linehaul',style:TextStyle(fontWeight:FontWeight.w800)),actions:[IconButton(onPressed:_busy?null:_load,icon:const Icon(Icons.refresh))]),body:_busy&&_trips.isEmpty?const Center(child:CircularProgressIndicator()):pages[_tab],bottomNavigationBar:ShopHopNavigation(index:_tab,onChanged:(i){if(_scanning&&i!=1){_camera.stop();_scanning=false;}setState(()=>_tab=i);},items:const[
      ShopHopNavItem('Trips',Icons.route_outlined,Icons.route_rounded),
      ShopHopNavItem('Scan',Icons.qr_code_scanner_rounded,Icons.qr_code_scanner_rounded),
      ShopHopNavItem('Vehicle',Icons.local_shipping_outlined,Icons.local_shipping_rounded),
      ShopHopNavItem('History',Icons.history_outlined,Icons.history_rounded),
      ShopHopNavItem('Account',Icons.person_outline_rounded,Icons.person_rounded),
    ]));
  }
}

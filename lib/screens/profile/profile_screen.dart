import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../repositories/user_repository.dart';
import '../auth/login_screen.dart';
import '../auth/register_client_screen.dart';
import '../auth/register_provider_screen.dart';
import '../saved_screen.dart';
import '../my_requests_screen.dart';
import '../admin/admin_dashboard_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override Widget build(BuildContext context){
    final auth=FirebaseAuth.instance;
    final uid=auth.currentUser?.uid;
    if(uid==null)return _GuestProfile();
    return StreamBuilder<UserModel?>(stream:UserRepository().watchUser(uid),builder:(context,s){
      if(s.connectionState==ConnectionState.waiting)return const Center(child:CircularProgressIndicator());
      final user=s.data;
      if(user==null)return _GuestProfile();
      return _LoggedInProfile(user:user);
    });
  }
}

class _GuestProfile extends StatelessWidget{
  @override Widget build(BuildContext context)=>Scaffold(body:SafeArea(child:ListView(padding:const EdgeInsets.all(24),children:[
    const SizedBox(height:24),Center(child:CircleAvatar(radius:56,child:Icon(Icons.person,size:56))),const SizedBox(height:24),
    const Text('Welcome to FindiPro',style:TextStyle(fontSize:28,fontWeight:FontWeight.w700)),const SizedBox(height:8),
    const Text('Find trusted professionals, request services, save providers and chat securely.',style:TextStyle(color:Colors.black54,height:1.5)),const SizedBox(height:28),
    ElevatedButton(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const LoginScreen())),child:const Text('Login')),const SizedBox(height:12),
    OutlinedButton(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const RegisterClientScreen())),child:const Text('Sign up as Client')),const SizedBox(height:12),
    ElevatedButton.icon(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const RegisterProviderScreen())),icon:const Icon(Icons.work_outline),label:const Text('Become a Service Provider')),
  ])));
}

class _LoggedInProfile extends StatelessWidget{
  final UserModel user; const _LoggedInProfile({required this.user});
  @override Widget build(BuildContext context)=>Scaffold(body:SafeArea(child:ListView(padding:const EdgeInsets.all(20),children:[
    Row(children:[CircleAvatar(radius:34,backgroundImage:user.photoUrl==null?null:NetworkImage(user.photoUrl!),child:user.photoUrl==null?const Icon(Icons.person,size:34):null),const SizedBox(width:14),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(user.name.isEmpty?'FindiPro User':user.name,style:const TextStyle(fontSize:22,fontWeight:FontWeight.w700)),const SizedBox(height:4),Text(user.email,style:const TextStyle(color:Colors.black54)),if (user.isAdmin) const Text('Admin', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)) else Text(user.role=='provider'?'Service Provider':'Client',style:const TextStyle(color:Color(0xFF06B6D4),fontWeight:FontWeight.w600))]))]),
    const SizedBox(height:28),
    if(user.isAdmin)...[_tile(context,Icons.admin_panel_settings,'Admin dashboard',()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const AdminDashboardScreen()))),],
    if(user.role=='provider')...[
      _tile(context,Icons.work_outline,'Provider dashboard',()=>ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Provider dashboard is available from your provider account.')))),
    ],
    _tile(context,Icons.receipt_long_outlined,'My requests',()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const MyRequestsScreen()))),
    _tile(context,Icons.bookmark_outline,'Saved providers',()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const SavedScreen()))),
    _tile(context,Icons.edit_outlined,'Edit profile',()=>ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Profile editing can be added without changing authentication.')))),
    const Divider(height:32),
    _tile(context,Icons.logout,'Logout',()async{await FirebaseAuth.instance.signOut();}),
  ])));
  Widget _tile(BuildContext c,IconData icon,String title,VoidCallback tap)=>ListTile(leading:Icon(icon),title:Text(title),trailing:const Icon(Icons.chevron_right),onTap:tap);
}

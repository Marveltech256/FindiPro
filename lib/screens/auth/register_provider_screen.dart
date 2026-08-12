import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/auth_service.dart';
import '../../services/storage_service.dart';
import '../../services/location_service.dart';
import '../../repositories/user_repository.dart';

class RegisterProviderScreen extends StatefulWidget {
  const RegisterProviderScreen({super.key});
  @override State<RegisterProviderScreen> createState() => _RegisterProviderScreenState();
}

class _RegisterProviderScreenState extends State<RegisterProviderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name=TextEditingController(), _email=TextEditingController(), _phone=TextEditingController(), _location=TextEditingController(), _about=TextEditingController(), _price=TextEditingController(), _skills=TextEditingController(), _business=TextEditingController(), _years=TextEditingController();
  final _categories = const ['Plumbing','Electrical','Cleaning','Mechanic','Painting','Gardening','Carpentry','Moving','Beauty','Construction','IT & Technology','Other'];
  String? _category; File? _image; bool _loading=false; bool _obscure=true; bool _obscureConfirm=true;
  final _password=TextEditingController(), _confirm=TextEditingController();
  final _picker=ImagePicker(); final _auth=AuthService(); final _storage=StorageService(); final _users=UserRepository(); final _locationService=LocationService();

  @override void dispose(){ for(final c in [_name,_email,_phone,_location,_about,_price,_skills,_business,_years,_password,_confirm]){c.dispose();} super.dispose(); }
  Future<void> _pickImage() async { final x=await _picker.pickImage(source: ImageSource.gallery,imageQuality:85,maxWidth:1600,maxHeight:1600); if(x!=null)setState(()=>_image=File(x.path)); }

  Future<void> _register() async {
    if(!_formKey.currentState!.validate())return;
    setState(()=>_loading=true);
    try {
      final credential=await _auth.register(name:_name.text,email:_email.text,phone:_phone.text,password:_password.text,role:'provider');
      final uid=credential.user!.uid;
      String? photoUrl;
      if(_image!=null){try{photoUrl=await _storage.uploadImage(file:_image!,path:'providers/$uid/profile/profile.jpg');}catch(_){}}
      Position? pos;
      try { pos=await _locationService.getCurrentLocation(); } catch (_) {}
      final skills=_skills.text.split(',').map((s)=>s.trim()).where((s)=>s.isNotEmpty).toList();
      await _users.createProvider(uid:uid,name:_name.text.trim(),email:_email.text.trim(),phone:_phone.text.trim(),category:_category!,location:_location.text.trim(),yearsExperience:int.tryParse(_years.text.trim())??0,about:_about.text.trim(),bio:_about.text.trim(),skills:skills,priceRange:_price.text.trim(),available:true,latitude:pos?.latitude,longitude:pos?.longitude,photoUrl:photoUrl,businessName:_business.text.trim().isEmpty?null:_business.text.trim());
      if(mounted){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Provider account created. Your profile is pending approval.')));Navigator.pop(context);}
    } on FirebaseAuthException catch(e){if(mounted)_show(e.message??'Registration failed.');}
    catch(e){if(mounted)_show('Registration failed. If you selected a photo, confirm Firebase Storage is enabled.');}
    finally{if(mounted)setState(()=>_loading=false);}
  }
  void _show(String s)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));

  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Become a Service Provider')),body:SafeArea(child:Form(key:_formKey,child:ListView(padding:const EdgeInsets.all(24),children:[
    Center(child:GestureDetector(onTap:_loading?null:_pickImage,child:CircleAvatar(radius:56,backgroundImage:_image==null?null:FileImage(_image!),child:_image==null?const Icon(Icons.add_a_photo,size:32):null))),
    const SizedBox(height:22),
    TextFormField(controller:_name,decoration:const InputDecoration(labelText:'Full name'),validator:(v)=>v==null||v.trim().length<2?'Enter your name':null),const SizedBox(height:14),
    TextFormField(controller:_business,decoration:const InputDecoration(labelText:'Business name (optional)')),const SizedBox(height:14),
    TextFormField(controller:_email,keyboardType:TextInputType.emailAddress,decoration:const InputDecoration(labelText:'Email'),validator:(v)=>v==null||!v.contains('@')?'Enter a valid email':null),const SizedBox(height:14),
    TextFormField(controller:_phone,keyboardType:TextInputType.phone,decoration:const InputDecoration(labelText:'Phone / WhatsApp'),validator:(v)=>v==null||v.trim().length<7?'Enter a valid phone number':null),const SizedBox(height:14),
    DropdownButtonFormField<String>(initialValue:_category,decoration:const InputDecoration(labelText:'Profession / service category'),items:_categories.map((c)=>DropdownMenuItem(value:c,child:Text(c))).toList(),onChanged:_loading?null:(v)=>setState(()=>_category=v),validator:(v)=>v==null?'Select your profession':null),const SizedBox(height:14),
    TextFormField(controller:_location,decoration:const InputDecoration(labelText:'Service location / area'),validator:(v)=>v==null||v.trim().isEmpty?'Enter your service area':null),const SizedBox(height:14),
    TextFormField(controller:_years,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Years of experience'),validator:(v)=>v==null||int.tryParse(v)==null?'Enter years of experience':null),const SizedBox(height:14),
    TextFormField(controller:_price,decoration:const InputDecoration(labelText:'Price / rate range')),const SizedBox(height:14),
    TextFormField(controller:_skills,decoration:const InputDecoration(labelText:'Skills / services (comma separated)')),const SizedBox(height:14),
    TextFormField(controller:_about,maxLines:5,decoration:const InputDecoration(labelText:'About your professional service'),validator:(v)=>v==null||v.trim().length<20?'Tell clients a little more about your service':null),const SizedBox(height:14),
    TextFormField(controller:_password,obscureText:_obscure,decoration:InputDecoration(labelText:'Password',suffixIcon:IconButton(onPressed:()=>setState(()=>_obscure=!_obscure),icon:Icon(_obscure?Icons.visibility:Icons.visibility_off))),validator:(v)=>v==null||v.length<6?'Minimum 6 characters':null),const SizedBox(height:14),
    TextFormField(controller:_confirm,obscureText:_obscureConfirm,decoration:InputDecoration(labelText:'Confirm password',suffixIcon:IconButton(onPressed:()=>setState(()=>_obscureConfirm=!_obscureConfirm),icon:Icon(_obscureConfirm?Icons.visibility:Icons.visibility_off))),validator:(v)=>v!=_password.text?'Passwords do not match':null),
    const SizedBox(height:24),SizedBox(height:52,child:ElevatedButton(onPressed:_loading?null:_register,child:_loading?const CircularProgressIndicator.adaptive():const Text('Create provider account'))),
  ]))));
}

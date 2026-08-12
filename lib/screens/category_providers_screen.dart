import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../repositories/user_repository.dart';
import 'Provider/provider_detail_screen.dart';

class CategoryProvidersScreen extends StatelessWidget {
  final String category; const CategoryProvidersScreen({super.key,required this.category});
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(category)),body:StreamBuilder<List<UserModel>>(stream:UserRepository().getProvidersStream(),builder:(context,s){
    if(s.hasError)return Center(child:Text('Unable to load providers.'));
    if(!s.hasData)return const Center(child:CircularProgressIndicator());
    final providers=s.data!.where((p)=>(p.category??'').toLowerCase()==category.toLowerCase()).toList();
    if(providers.isEmpty)return Center(child:Text('No approved providers found for $category.'));
    return ListView.separated(padding:const EdgeInsets.all(16),itemCount:providers.length,separatorBuilder:(_,__)=>const SizedBox(height:10),itemBuilder:(context,i){final p=providers[i];return ListTile(tileColor:Colors.white,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18)),leading:CircleAvatar(backgroundImage:p.photoUrl==null?null:NetworkImage(p.photoUrl!),child:p.photoUrl==null?const Icon(Icons.person):null),title:Text(p.businessName?.isNotEmpty==true?p.businessName!:p.name,style:const TextStyle(fontWeight:FontWeight.w700)),subtitle:Text('${p.location??'Location not specified'} • ${p.rating.toStringAsFixed(1)} ★'),trailing:const Icon(Icons.chevron_right),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>ProviderDetailScreen(provider:p))));});
  }));
}

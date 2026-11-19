import 'dart:convert';
import 'descriptor_wheel.dart';
import 'social_feed.dart';
import 'tea_diary.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const ChaTara());
const ink = Color(0xff292b22), green = Color(0xff657052), paper = Color(0xfff2eddf), accent = Color(0xffa76743);
const categories = ['Белый чай','Зелёный чай','Жёлтый чай','Улуны','Красный чай','Пуэр','Хэй ча','GABA'];
const symbols = ['白','绿','黄','青','红','普','黑','G'];
const colors = [Color(0xffd8d0bc),Color(0xff657052),Color(0xffad9157),Color(0xff527b78),Color(0xff985044),Color(0xff80603c),Color(0xff343732),Color(0xff81758e)];
const descriptions = ['Лёгкость · чистота · нежность','Свежесть · гармония · энергия','Мягкость · глубина · баланс','Многогранность · глубина · вдохновение','Тепло · насыщенность · характер','Время · глубина · трансформация','Плотность · устойчивость · сила','Спокойствие · ясность · гармония'];
const teas = <String,List<String>>{'Белый чай':['Бай Хао Инь Чжэнь','Бай Му Дань','Шоу Мэй'],'Зелёный чай':['Лунцзин','Билочунь','Маофэн'],'Жёлтый чай':['Цзюнь Шань Инь Чжэнь','Хошань Хуан Я'],'Улуны':['Да Хун Пао','Те Гуань Инь','Дун Дин'],'Красный чай':['Цзинь Цзюнь Мэй','Дянь Хун','Цимэнь Хун Ча'],'Пуэр':['Шэн пуэр','Шу пуэр'],'Хэй ча':['Лю Бао','Фу Чжуань'],'GABA':['GABA улун','GABA красный']};

class ChaTara extends StatelessWidget {const ChaTara({super.key}); @override Widget build(BuildContext c)=>MaterialApp(title:'Cha Tara',debugShowCheckedModeBanner:false,theme:ThemeData(colorScheme:ColorScheme.fromSeed(seedColor:green,surface:paper),scaffoldBackgroundColor:paper,useMaterial3:true,navigationBarTheme:NavigationBarThemeData(labelTextStyle:WidgetStateProperty.all(const TextStyle(fontSize:10,letterSpacing:-0.3))),textTheme:ThemeData.light().textTheme.apply(bodyColor:ink,displayColor:ink), inputDecorationTheme:InputDecorationTheme(filled:true,fillColor:const Color(0xfffaf7ed),border:OutlineInputBorder(borderRadius:BorderRadius.circular(18),borderSide:BorderSide.none)),cardTheme:CardThemeData(color:const Color(0xfffaf7ed),elevation:0,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(20)))),home:const Home());}
class Home extends StatefulWidget {const Home({super.key}); @override State<Home> createState()=>_HomeState();}
class _HomeState extends State<Home>{int page=0; List<Map<String,dynamic>> entries=[]; String selected=''; final custom=TextEditingController(), grams=TextEditingController(text:'5'), water=TextEditingController(text:'150'), temp=TextEditingController(text:'90'), seconds=TextEditingController(text:'60'), notes=TextEditingController(), searchController=TextEditingController(); int infusion=1; String tab='Аромат'; final Set<String> descriptors={}; String query='';
@override void dispose(){custom.dispose();grams.dispose();water.dispose();temp.dispose();seconds.dispose();notes.dispose();searchController.dispose();super.dispose();}
@override void initState(){super.initState();load();} Future<void> load() async {final p=await SharedPreferences.getInstance(); final data=p.getString('sessions'); if(data!=null){try {entries=(jsonDecode(data) as List).map((e)=>Map<String,dynamic>.from(e)).toList();} catch (_) {} } if(mounted)setState((){});}
Future<void> save() async {if(selected.isEmpty){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Сначала выберите чай или введите свой')));return;} entries.insert(0,{'tea':selected,'date':DateTime.now().toIso8601String(),'grams':grams.text,'water':water.text,'temp':temp.text,'seconds':seconds.text,'infusion':infusion,'notes':notes.text,'descriptors':descriptors.toList()}); final p=await SharedPreferences.getInstance(); await p.setString('sessions',jsonEncode(entries)); notes.clear(); descriptors.clear(); setState(()=>page=2); if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Сессия сохранена в дневник')));}
void category(int i){Navigator.push(context,MaterialPageRoute(builder:(ctx)=>Scaffold(appBar:AppBar(backgroundColor:paper,title:Text(categories[i],style:serif(24))),body:ListView(padding:const EdgeInsets.all(20),children:[Text(descriptions[i],style:const TextStyle(color:green,letterSpacing:1)),const SizedBox(height:20),...teas[categories[i]]!.map((t)=>Card(child:ListTile(contentPadding:const EdgeInsets.all(16),leading:CircleAvatar(backgroundColor:colors[i],child:Text(symbols[i],style:const TextStyle(color:Colors.white))),title:Text(t,style:serif(20)),subtitle:Text(categories[i]),trailing:const Icon(Icons.arrow_forward_ios,size:16),onTap:(){setState((){selected=t;page=3;});Navigator.pop(ctx);}))),const SizedBox(height:12),const Text('Выберите чай, чтобы начать сессию.')]))));}
TextStyle serif(double size,{Color color=ink})=>TextStyle(fontFamily:'Georgia',fontSize:size,color:color,height:1.08);
Widget heading(String title,String subtitle)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:serif(34)),const SizedBox(height:8),Text(subtitle,style:const TextStyle(color:Color(0xff77786b),fontSize:14)),const SizedBox(height:24)]);
Widget block(String title,String sub,IconData icon,VoidCallback onTap)=>Card(child:ListTile(contentPadding:const EdgeInsets.symmetric(horizontal:18,vertical:10),leading:CircleAvatar(backgroundColor:const Color(0xffe2dfcd),child:Icon(icon,color:green)),title:Text(title,style:serif(21)),subtitle:Padding(padding:const EdgeInsets.only(top:6),child:Text(sub)),trailing:const Icon(Icons.arrow_forward_ios,size:16),onTap:onTap));
Widget homeAction(
  String title,
  String subtitle,
  IconData icon,
  VoidCallback onTap,
) {
  return Card(
    margin: const EdgeInsets.only(bottom: 8),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: LayoutBuilder(builder: (context, constraints) {
          final compact = constraints.maxWidth < 252 ||
              MediaQuery.textScalerOf(context).scale(19) > 23;
          final badge = CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xffe2dfcd),
            child: Icon(icon, size: 18, color: green),
          );
          const arrow = Icon(Icons.chevron_right, size: 19, color: green);
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: serif(19)),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(fontSize: 14, height: 1.3)),
            ],
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [badge, arrow]),
                const SizedBox(height: 8),
                copy,
              ],
            );
          }
          return Row(children: [
            badge,
            const SizedBox(width: 12),
            Expanded(child: copy),
            const SizedBox(width: 8),
            arrow,
          ]);
        }),
      ),
    ),
  );
}

Widget home() => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    heading('Чайный компас', 'Чай · люди · места · культура'),
    ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 1.7,
            child: Image.asset(
              'assets/brand.jpg',
              fit: BoxFit.cover,
              alignment: const Alignment(0, -.35),
              excludeFromSemantics: true,
            ),
          ),
          ColoredBox(
            color: const Color(0xff342e22),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              child: Text(
                'В каждой чашке чая скрыта тишина мира',
                textAlign: TextAlign.center,
                style: serif(20, color: const Color(0xfff5eddb)).copyWith(height: 1.25),
              ),
            ),
          ),
        ],
      ),
    ),
    const SizedBox(height: 22),
    Text('Ваш чайный путь', style: serif(25)),
    const SizedBox(height: 10),
    homeAction(
      'Начать сессию',
      'Заварите чай и сохраните впечатления',
      Icons.local_fire_department_outlined,
      () => setState(() => page = 3),
    ),
    homeAction(
      'Открыть энциклопедию',
      'Исследуйте мир чайных вкусов',
      Icons.menu_book_outlined,
      () => setState(() => page = 4),
    ),
    if (FeedApi.enabled) ...[const SizedBox(height: 16), const SocialFeed()],
  ],
);
Widget master()=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[heading('Мастер Чи','Ваш проводник в мире чая'),Card(child:Padding(padding:const EdgeInsets.all(22),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Чай начинается\nс внимания.',style:serif(28)),const SizedBox(height:12),const Text('Выберите чай в энциклопедии, а затем запишите свои ощущения после каждого пролива.'),const SizedBox(height:12),TextButton(onPressed:()=>setState(()=>page=4),child:const Text('Выбрать чай →'))]))),const SizedBox(height:20),Text('Скоро появится',style:serif(22)),block('Распознать по фото','Помощь с чаем и этикеткой',Icons.camera_alt_outlined,coming),block('Подобрать чай','Чай под ваше настроение',Icons.spa_outlined,coming),block('Задать вопрос','Поговорить с Мастером Чи',Icons.chat_bubble_outline,coming)]);
void coming()=>ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Эта возможность появится позже')));
Future<void> shareEntry(Map<String, dynamic> entry) async {
  if (!await FeedApi.requireAccount(context) || !mounted) return;
  final shared = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PublishTeaSession(entry: entry),
  );
  if (mounted && shared == true) {
    setState(() => page = 0);
  }
}
Future<void> deleteEntry(Map<String, dynamic> entry) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Удалить запись из дневника?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Отмена'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Удалить'),
        ),
      ],
    ),
  );
  if (confirmed != true || !mounted) return;
  setState(() => entries.remove(entry));
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('sessions', jsonEncode(entries));
}

Widget diary() => TeaDiary(
  entries: entries,
  onStart: () => setState(() => page = 3),
  onDelete: deleteEntry,
  onShare: FeedApi.enabled ? shareEntry : null,
);
Widget field(String label,TextEditingController controller,String suffix)=>Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Padding(padding:const EdgeInsets.only(left:4,bottom:6),child:Text(label,style:const TextStyle(fontSize:13,color:green))),TextField(controller:controller,keyboardType:TextInputType.number,decoration:InputDecoration(suffixText:suffix,contentPadding:const EdgeInsets.symmetric(horizontal:16,vertical:14),isDense:true))]));
Widget session()=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[heading('Чайная сессия','Найдите время для себя'),Card(child:ListTile(contentPadding:const EdgeInsets.all(16),title:Text(selected.isEmpty?'Выберите чай':selected,style:serif(24)),subtitle:Text(selected.isEmpty?'Из энциклопедии или введите свой':'Выбранный чай'),trailing:TextButton(onPressed:()=>setState(()=>page=4),child:const Text('Выбрать')))),const SizedBox(height:12),TextField(controller:custom,decoration:InputDecoration(hintText:'Или введите свой чай',suffixIcon:IconButton(icon:const Icon(Icons.arrow_forward),onPressed:(){if(custom.text.trim().isNotEmpty)setState(()=>selected=custom.text.trim());})),onSubmitted:(s){if(s.trim().isNotEmpty)setState(()=>selected=s.trim());}),const SizedBox(height:24),Text('Параметры заваривания',style:serif(24)),const SizedBox(height:12),Row(crossAxisAlignment:CrossAxisAlignment.start,children:[field('Чай',grams,'г'),const SizedBox(width:10),field('Вода',water,'мл')]),const SizedBox(height:16),Row(crossAxisAlignment:CrossAxisAlignment.start,children:[field('Температура',temp,'°C'),const SizedBox(width:10),field('Время',seconds,'сек')]),const SizedBox(height:24),Text('Пролив',style:serif(25)),const SizedBox(height:8),Wrap(spacing:8,children:List.generate(5,(i)=>ChoiceChip(label:Text('${i+1}'),selected:infusion==i+1,onSelected:(_)=>setState(()=>infusion=i+1)))),const SizedBox(height:20),Text('Впечатления',style:serif(25)),const SizedBox(height:10),Wrap(spacing:7,children:['Аромат','Вкус','Послевкусие'].map((t)=>ChoiceChip(label:Text(t),selected:tab==t,onSelected:(_)=>setState(()=>tab=t))).toList()),const SizedBox(height:12),DescriptorWheel(type:tab,infusion:infusion,selected:descriptors,onChanged:(key,value)=>setState((){if(value){descriptors.add(key);}else{descriptors.remove(key);}})),const SizedBox(height:12),TextField(controller:notes,maxLines:3,decoration:const InputDecoration(hintText:'Ваши заметки о чае...')),const SizedBox(height:18),SizedBox(width:double.infinity,child:FilledButton(onPressed:save,style:FilledButton.styleFrom(backgroundColor:green,padding:const EdgeInsets.all(16)),child:const Text('Сохранить сессию')))]);
Widget catalog()=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[heading('Энциклопедия чая','Откройте мир вкусов и чайной культуры'),TextField(controller:searchController,onChanged:(v)=>setState(()=>query=v.trim().toLowerCase()),decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'Найти чай или категорию')),const SizedBox(height:18),...List.generate(categories.length,(i){final matches=teas[categories[i]]!.where((t)=>t.toLowerCase().contains(query)).toList(); if(query.isNotEmpty&&!categories[i].toLowerCase().contains(query)&&matches.isEmpty)return const SizedBox.shrink();return Padding(padding:const EdgeInsets.only(bottom:8),child:Material(color:colors[i],borderRadius:BorderRadius.circular(16),child:InkWell(borderRadius:BorderRadius.circular(16),onTap:()=>category(i),child:Container(height:105,padding:const EdgeInsets.symmetric(horizontal:18),child:Row(children:[Text(symbols[i],style:serif(40,color:i==0||i==2?ink:Colors.white)),const SizedBox(width:18),Expanded(child:Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.start,children:[Text(categories[i],style:serif(23,color:i==0||i==2?ink:Colors.white)),const SizedBox(height:7),Text(descriptions[i],maxLines:2,style:TextStyle(fontSize:11,color:i==0||i==2?ink:Colors.white70,letterSpacing:.3))])),Icon(Icons.arrow_forward_ios,size:18,color:i==0||i==2?ink:Colors.white)])))));})]);
@override
Widget build(BuildContext context) {
  const pageWidth = 600.0;
  const pageInset = 20.0;
  final pages = [home, master, diary, session, catalog];
  final wideLayout = MediaQuery.sizeOf(context).width > pageWidth;
  final navigationTheme = NavigationBarTheme.of(context);

  return Scaffold(
    appBar: AppBar(
      backgroundColor: paper,
      centerTitle: true,
      title: const Text(
        'C H A   ✦   T A R A',
        style: TextStyle(fontFamily: 'Georgia', fontSize: 16, letterSpacing: 1.5),
      ),
    ),
    body: Align(
      alignment: page == 2 ? Alignment.topCenter : Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: pageWidth),
        child: SingleChildScrollView(
          key: ValueKey(page),
          padding: const EdgeInsets.fromLTRB(pageInset, 12, pageInset, 32),
          child: pages[page](),
        ),
      ),
    ),
    bottomNavigationBar: Align(
      alignment: Alignment.bottomCenter,
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: wideLayout ? pageWidth - 2 * pageInset : pageWidth,
        ),
        child: NavigationBarTheme(
          data: wideLayout
              ? navigationTheme.copyWith(
                  labelTextStyle: const WidgetStatePropertyAll(
                    TextStyle(fontSize: 14),
                  ),
                )
              : navigationTheme,
          child: NavigationBar(
            height: 72,
            backgroundColor: const Color(0xffe9e4d5),
            indicatorColor: const Color(0xffd7deca),
            selectedIndex: page,
            onDestinationSelected: (index) => setState(() => page = index),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Лента'),
              NavigationDestination(icon: Icon(Icons.spa_outlined), label: 'Мастер Чи'),
              NavigationDestination(icon: Icon(Icons.auto_stories_outlined), label: 'Дневник'),
              NavigationDestination(icon: Icon(Icons.local_fire_department_outlined), label: 'Сессия'),
              NavigationDestination(icon: Icon(Icons.school_outlined), label: 'Чай'),
            ],
          ),
        ),
      ),
    ),
  );
}
}

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Task Manager',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: AuthGate(),
    );
  }
}

// 🔐 Login / SignUp Screen
class AuthGate extends StatefulWidget {
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final emailController = TextEditingController();
  final passController = TextEditingController();

  Future<void> login() async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text,
        password: passController.text,
      );
    } catch (e) {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text,
        password: passController.text,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.hasData) return TaskListScreen();

        return Scaffold(
          appBar: AppBar(title: Text("Login or Sign Up")),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(controller: emailController, decoration: InputDecoration(labelText: "Email")),
                TextField(controller: passController, decoration: InputDecoration(labelText: "Password"), obscureText: true),
                ElevatedButton(onPressed: login, child: Text("Continue")),
              ],
            ),
          ),
        );
      },
    );
  }
}

// 📋 Main Task List Screen
class TaskListScreen extends StatefulWidget {
  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  final taskController = TextEditingController();
  final user = FirebaseAuth.instance.currentUser!;
  late CollectionReference tasksRef;

  @override
  void initState() {
    super.initState();
    tasksRef = FirebaseFirestore.instance.collection("users").doc(user.uid).collection("tasks");
  }

  Future<void> addTask(String name) async {
    if (name.isEmpty) return;
    await tasksRef.add({
      'name': name,
      'completed': false,
      'subtasks': [
        {'time': '9 AM - 10 AM', 'title': 'HW1, Essay2'},
        {'time': '12 PM - 2 PM', 'title': 'Read Book, Call Mom'}
      ]
    });
    taskController.clear();
  }

  Future<void> toggleComplete(DocumentSnapshot doc) async {
    await tasksRef.doc(doc.id).update({'completed': !(doc['completed'] ?? false)});
  }

  Future<void> deleteTask(String id) async {
    await tasksRef.doc(id).delete();
  }

  Widget buildSubtasks(List<dynamic> subtasks) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: subtasks.map((sub) {
        return Padding(
          padding: const EdgeInsets.only(left: 16.0, top: 4),
          child: Text("- ${sub['time']}: ${sub['title']}"),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Your Tasks"),
        actions: [
          IconButton(onPressed: () => FirebaseAuth.instance.signOut(), icon: Icon(Icons.logout))
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(child: TextField(controller: taskController, decoration: InputDecoration(labelText: "New Task"))),
                SizedBox(width: 8),
                ElevatedButton(onPressed: () => addTask(taskController.text), child: Text("Add")),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: tasksRef.snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

                final docs = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final name = doc['name'];
                    final completed = doc['completed'] ?? false;
                    final subtasks = doc['subtasks'] ?? [];

                    return Card(
                      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        leading: Checkbox(value: completed, onChanged: (_) => toggleComplete(doc)),
                        title: Text(name),
                        subtitle: buildSubtasks(subtasks),
                        trailing: IconButton(icon: Icon(Icons.delete), onPressed: () => deleteTask(doc.id)),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

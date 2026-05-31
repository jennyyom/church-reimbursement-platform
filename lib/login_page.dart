import 'package:flutter/material.dart';

class LoginPage extends StatelessWidget {
    const LoginPage({super.key});

@override
Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.indigo.shade50,
        appBar: AppBar(
            title: const Text('Sign In'),
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
        ),

        body: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                    const TextField(
                        decoration: InputDecoration(
                            labelText: 'Email',
                            border: OutlineInputBorder(),
                        ),
                    ),
                    const SizedBox(height: 16),
                    const TextField(
                        obscureText: true,
                        decoration: InputDecoration(
                            labelText: 'Password',
                            border: OutlineInputBorder(),
                        ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                        onPressed: () {},
                        child: const Text('Sign In'),
                    ),
                ],
            ),
        ),
    );
}
}
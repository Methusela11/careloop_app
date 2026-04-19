import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final ImagePicker _imagePicker = ImagePicker();

  Map<String, dynamic>? userData;
  bool isLoading = true;
  bool isUploading = false;
  bool isEditing = false;

  // Text editing controllers for editing mode
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final data = await _authService.getUserData(user.uid);
      setState(() {
        userData = data;
        isLoading = false;
        // Initialize controllers with current data
        _fullNameController.text = data?["fullName"] ?? "";
        _usernameController.text = data?["username"] ?? "";
        _emailController.text = data?["email"] ?? "";
      });
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _pickAndUploadProfilePicture() async {
    try {
      showModalBottomSheet(
        context: context,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text("Choose from Gallery"),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text("Take a Photo"),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      _showSnackBar("Error: $e");
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          isUploading = true;
        });

        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          String imageUrl = await _authService.uploadProfilePicture(
            File(pickedFile.path),
            user.uid,
          );

          setState(() {
            userData?["profileImageUrl"] = imageUrl;
            isUploading = false;
          });

          _showSnackBar("Profile picture updated successfully!");
        }
      }
    } catch (e) {
      setState(() {
        isUploading = false;
      });
      _showSnackBar("Failed to upload image: $e");
    }
  }

  Future<void> _updateProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      isLoading = true;
    });

    try {
      // Update Firestore
      await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .update({
        "fullName": _fullNameController.text.trim(),
        "username": _usernameController.text.trim().toLowerCase(),
        "email": _emailController.text.trim(),
      });

      // Update local data
      setState(() {
        userData?["fullName"] = _fullNameController.text.trim();
        userData?["username"] = _usernameController.text.trim().toLowerCase();
        userData?["email"] = _emailController.text.trim();
        isEditing = false;
        isLoading = false;
      });

      _showSnackBar("Profile updated successfully!");
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      _showSnackBar("Failed to update profile: $e");
    }
  }

  Future<void> _signOut() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Sign Out"),
        content: const Text("Are you sure you want to sign out?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _authService.logout();
              if (mounted) {
                Navigator.pushReplacementNamed(context, "/login");
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Sign Out"),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Profile"),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          if (!isEditing && !isLoading)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                setState(() {
                  isEditing = true;
                });
              },
            ),
          if (isEditing)
            TextButton(
              onPressed: () {
                setState(() {
                  isEditing = false;
                  // Reset controllers to original values
                  _fullNameController.text = userData?["fullName"] ?? "";
                  _usernameController.text = userData?["username"] ?? "";
                  _emailController.text = userData?["email"] ?? "";
                });
              },
              child: const Text(
                "Cancel",
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : userData == null
              ? const Center(child: Text("No user data found"))
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      // Profile Picture Section
                      Container(
                        color: Colors.teal.shade50,
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Stack(
                              children: [
                                GestureDetector(
                                  onTap: _pickAndUploadProfilePicture,
                                  child: CircleAvatar(
                                    radius: 70,
                                    backgroundColor: Colors.grey[300],
                                    backgroundImage:
                                        userData!["profileImageUrl"] != null &&
                                                userData!["profileImageUrl"]
                                                    .toString()
                                                    .isNotEmpty
                                            ? NetworkImage(
                                                userData!["profileImageUrl"])
                                            : null,
                                    child:
                                        userData!["profileImageUrl"] == null ||
                                                userData!["profileImageUrl"]
                                                    .toString()
                                                    .isEmpty
                                            ? Icon(
                                                Icons.person,
                                                size: 70,
                                                color: Colors.grey[700],
                                              )
                                            : null,
                                  ),
                                ),
                                if (isUploading)
                                  const Positioned.fill(
                                    child: CircleAvatar(
                                      radius: 70,
                                      backgroundColor: Colors.black54,
                                      child: CircularProgressIndicator(),
                                    ),
                                  ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.teal,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.white, width: 3),
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt,
                                      size: 24,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              userData!["fullName"] ?? "User",
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "@${userData!["username"] ?? "username"}",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Profile Details Section
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Profile Information",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Full Name Field
                            _buildProfileField(
                              icon: Icons.person,
                              label: "Full Name",
                              value: userData!["fullName"] ?? "N/A",
                              controller: _fullNameController,
                              isEditing: isEditing,
                            ),

                            const SizedBox(height: 16),

                            // Username Field
                            _buildProfileField(
                              icon: Icons.alternate_email,
                              label: "Username",
                              value: "@${userData!["username"] ?? "N/A"}",
                              controller: _usernameController,
                              isEditing: isEditing,
                              prefix: "@",
                            ),

                            const SizedBox(height: 16),

                            // Email Field
                            _buildProfileField(
                              icon: Icons.email,
                              label: "Email",
                              value: userData!["email"] ?? "N/A",
                              controller: _emailController,
                              isEditing: isEditing,
                              keyboardType: TextInputType.emailAddress,
                            ),

                            const SizedBox(height: 16),

                            // Role (Read-only)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.teal.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.assignment_ind,
                                      color: Colors.teal.shade800,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Role",
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        Text(
                                          userData!["role"] ?? "N/A",
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Update Button (when editing)
                            if (isEditing)
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _updateProfile,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.teal,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    "Save Changes",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),

                            const SizedBox(height: 16),

                            // Sign Out Button
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: _signOut,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  "Sign Out",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildProfileField({
    required IconData icon,
    required String label,
    required String value,
    required TextEditingController controller,
    required bool isEditing,
    String? prefix,
    TextInputType? keyboardType,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.teal.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: Colors.teal.shade800,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                if (isEditing)
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      prefixText: prefix,
                    ),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    keyboardType: keyboardType,
                  )
                else
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

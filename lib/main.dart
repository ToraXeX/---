import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

void main() {
  runApp(PhotoGalleryApp());
}

class PhotoGalleryApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: PhotoGalleryPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class PhotoGalleryPage extends StatefulWidget {
  @override
  _PhotoGalleryPageState createState() => _PhotoGalleryPageState();
}

class _PhotoGalleryPageState extends State<PhotoGalleryPage> {
  late Database _database;
  final ImagePicker _picker = ImagePicker();
  List<Map<String, dynamic>> _photos = [];
  String? _backgroundImage;

  @override
  void initState() {
    super.initState();
    _initDatabase();
    _loadBackgroundImage();
  }

  Future<void> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = p.join(documentsDirectory.path, 'photos.db');

    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE photos (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            path TEXT,
            note TEXT
          )
        ''');
      },
    );

    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    try {
      final photos = await _database.query('photos');
      setState(() {
        _photos = photos;
      });
    } catch (e) {
      print('Ошибка при загрузке данных: $e');
    }
  }

  Future<void> _loadBackgroundImage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPath = prefs.getString('backgroundImage');
      if (savedPath != null && File(savedPath).existsSync()) {
        setState(() {
          _backgroundImage = savedPath;
        });
      } else {
        print('Сохраненное изображение не найдено или файл был удален.');
      }
    } catch (e) {
      print('Ошибка при загрузке фона: $e');
    }
  }

  Future<void> _setBackgroundImage() async {
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('backgroundImage', pickedFile.path);
        setState(() {
          _backgroundImage = pickedFile.path;
        });
        print('Новый фон установлен: ${pickedFile.path}');
      } else {
        print('Файл не выбран.');
      }
    } catch (e) {
      print('Ошибка при установке фона: $e');
    }
  }

  Future<void> _addPhoto(File image, String note) async {
    try {
      await _database.insert('photos', {
        'path': image.path,
        'note': note,
      });
      _loadPhotos();
    } catch (e) {
      print('Ошибка при добавлении фото: $e');
    }
  }

  Future<void> _updatePhoto(int id, {String? newNote, String? newPath}) async {
    try {
      final updates = <String, dynamic>{};
      if (newNote != null) updates['note'] = newNote;
      if (newPath != null) updates['path'] = newPath;

      await _database.update(
        'photos',
        updates,
        where: 'id = ?',
        whereArgs: [id],
      );
      _loadPhotos();
    } catch (e) {
      print('Ошибка при обновлении фото: $e');
    }
  }

  Future<void> _deletePhoto(int id) async {
    try {
      await _database.delete('photos', where: 'id = ?', whereArgs: [id]);
      _loadPhotos();
    } catch (e) {
      print('Ошибка при удалении фото: $e');
    }
  }

  void _openPhotoDetails(Map<String, dynamic> photo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PhotoDetailsPage(
          photo: photo,
          onUpdate: _updatePhoto,
          onDelete: _deletePhoto,
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(source: source);

      if (pickedFile != null) {
        final File image = File(pickedFile.path);

        final TextEditingController noteController = TextEditingController();

        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text('Добавить заметку'),
              content: TextField(
                controller: noteController,
                decoration: InputDecoration(hintText: 'Введите заметку...'),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (noteController.text.isNotEmpty) {
                      _addPhoto(image, noteController.text);
                      Navigator.of(context).pop();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Заметка не может быть пустой')),
                      );
                    }
                  },
                  child: Text('Сохранить'),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      print('Ошибка при добавлении изображения: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Фотогалерея'),
        actions: [
          IconButton(
            icon: Icon(Icons.image),
            onPressed: _setBackgroundImage,
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_backgroundImage != null && File(_backgroundImage!).existsSync())
            Positioned.fill(
              child: Image.file(
                File(_backgroundImage!),
                fit: BoxFit.cover,
              ),
            ),
          _photos.isEmpty
              ? Center(
            child: Text(
              'Нет фотографий. Нажмите "+" чтобы добавить.',
              style: TextStyle(fontSize: 16, color: Colors.white),
            ),
          )
              : ListView.builder(
            itemCount: _photos.length,
            itemBuilder: (context, index) {
              final photo = _photos[index];
              return Card(
                color: Colors.white70,
                child: ListTile(
                  leading: Image.file(
                    File(photo['path']),
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                  ),
                  title: Text(photo['note']),
                  onTap: () => _openPhotoDetails(photo),
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'camera',
            onPressed: () => _pickImage(ImageSource.camera),
            child: Icon(Icons.camera),
          ),
          SizedBox(height: 10),
          FloatingActionButton(
            heroTag: 'gallery',
            onPressed: () => _pickImage(ImageSource.gallery),
            child: Icon(Icons.photo_library),
          ),
        ],
      ),
    );
  }
}

class PhotoDetailsPage extends StatelessWidget {
  final Map<String, dynamic> photo;
  final Function(int id, {String? newNote, String? newPath}) onUpdate;
  final Function(int id) onDelete;

  PhotoDetailsPage({
    required this.photo,
    required this.onUpdate,
    required this.onDelete,
  });

  Future<void> _replacePhoto(BuildContext context) async {
    final ImagePicker picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final File newImage = File(pickedFile.path);
      onUpdate(photo['id'], newPath: newImage.path);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Фото обновлено')),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextEditingController noteController =
    TextEditingController(text: photo['note']);

    return Scaffold(
      appBar: AppBar(
        title: Text('Детали фотографии'),
        actions: [
          IconButton(
            icon: Icon(Icons.delete),
            onPressed: () {
              onDelete(photo['id']);
              Navigator.of(context).pop();
            },
          )
        ],
      ),
      body: Column(
        children: [
          Image.file(
            File(photo['path']),
            width: double.infinity,
            height: 300,
            fit: BoxFit.cover,
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: noteController,
              decoration: InputDecoration(
                labelText: 'Заметка',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              ElevatedButton(
                onPressed: () {
                  onUpdate(photo['id'], newNote: noteController.text);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Заметка обновлена')),
                  );
                  Navigator.of(context).pop();
                },
                child: Text('Сохранить изменения'),
              ),
              ElevatedButton(
                onPressed: () => _replacePhoto(context),
                child: Text('Заменить фото'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

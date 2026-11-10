import 'package:disaster/domain/entities/user_profile.dart';

abstract class UserRepository {
  Future<UserProfile?> getCurrent();
  Future<void> upsert(UserProfile user);
  Future<void> delete(String id);
}

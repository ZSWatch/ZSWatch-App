/// Base class for all repositories that map between database entities and domain models.
///
/// Provides a typed contract for the entity ↔ model conversion methods
/// that every repository must implement.
abstract class BaseRepository<Model, Entity> {
  /// Convert a database entity to a domain model.
  Model fromEntity(Entity entity);
}

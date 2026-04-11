/// Represents a friend (or the current user) in the friends list and leaderboard.
class Friend {
  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final bool isCurrentUser;
  final bool isLocationHidden;
  final int citiesCount;
  final int countriesCount;
  final DateTime addedAt;

  const Friend({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    this.isCurrentUser = false,
    this.isLocationHidden = false,
    this.citiesCount = 0,
    this.countriesCount = 0,
    required this.addedAt,
  });

  Friend copyWith({
    String? displayName,
    String? avatarUrl,
    bool? isLocationHidden,
    int? citiesCount,
    int? countriesCount,
  }) =>
      Friend(
        id: id,
        username: username,
        displayName: displayName ?? this.displayName,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        isCurrentUser: isCurrentUser,
        isLocationHidden: isLocationHidden ?? this.isLocationHidden,
        citiesCount: citiesCount ?? this.citiesCount,
        countriesCount: countriesCount ?? this.countriesCount,
        addedAt: addedAt,
      );
}
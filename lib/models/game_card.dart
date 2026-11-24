/// Şans / Kamu Fonu kartları.
/// (Flutter'daki `Card` widget'ı ile çakışmasın diye adı `GameCard`.)
enum CardDeck { chance, communityFund }

enum CardAction {
  /// [targetCity] iline (null ise Başlangıç'a) ilerle; Başlangıç'tan geçerse maaş al.
  advanceTo,

  /// En yakın ulaşım hattına ilerle (sahipliyse kira x[value]).
  advanceToNearestTransport,

  /// En yakın kamu kurumuna ilerle.
  advanceToNearestUtility,

  /// [value] kare geri git.
  moveBack,

  /// Doğrudan kodese git (Başlangıç'tan geçmez, maaş yok).
  goToJail,

  /// "Kodesten Çıkış" kartı — oyuncu saklar.
  getOutOfJail,

  /// Bankadan [value] al.
  receive,

  /// Bankaya [value] öde.
  pay,

  /// Her oyuncudan [value] topla.
  collectFromEach,

  /// Her oyuncuya [value] öde.
  payEach,

  /// Bina tamiri: ev başına [value], gökdelen başına [value2].
  repairs,
}

class GameCard {
  final int id;
  final CardDeck deck;
  final String text;
  final CardAction action;
  final int value;
  final int value2;
  /// Hedef il adı. Tüm haritalarda bulunan bir il olmalı (Ankara, İzmir, İstanbul).
  final String? targetCity;

  const GameCard({
    required this.id,
    required this.deck,
    required this.text,
    required this.action,
    this.value = 0,
    this.value2 = 0,
    this.targetCity,
  });

  /// Kodesten çıkış kartı oyuncu tarafından tutulur; desteye geri dönmez
  /// (kullanılınca geri konur).
  bool get isKeepable => action == CardAction.getOutOfJail;
}

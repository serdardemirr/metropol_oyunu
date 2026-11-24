import 'dart:math';

import '../models/game_card.dart';

/// Şans ve Kamu Fonu desteleri.
/// Kart id'leri benzersizdir: Şans 1xx, Kamu Fonu 2xx.
class CardData {
  CardData._();

  static const List<GameCard> chance = [
    GameCard(id: 101, deck: CardDeck.chance, text: 'Başlangıç noktasına ilerle ve maaşını al.', action: CardAction.advanceTo),
    GameCard(id: 102, deck: CardDeck.chance, text: 'En yakın ulaşım hattına ilerle.', action: CardAction.advanceToNearestTransport),
    GameCard(id: 103, deck: CardDeck.chance, text: 'En yakın ulaşım hattına ilerle.', action: CardAction.advanceToNearestTransport),
    GameCard(id: 104, deck: CardDeck.chance, text: 'En yakın kamu kurumuna ilerle.', action: CardAction.advanceToNearestUtility),
    GameCard(id: 105, deck: CardDeck.chance, text: "Başkent çağırıyor! Ankara'ya ilerle. Başlangıç'tan geçersen maaşını al.", action: CardAction.advanceTo, targetCity: 'Ankara'),
    GameCard(id: 106, deck: CardDeck.chance, text: "Boğaz'da bir davetiye! İstanbul'a ilerle.", action: CardAction.advanceTo, targetCity: 'İstanbul'),
    GameCard(id: 107, deck: CardDeck.chance, text: '3 kare geri git.', action: CardAction.moveBack, value: 3),
    GameCard(id: 108, deck: CardDeck.chance, text: "Doğrudan Kodese git! Başlangıç\'tan geçme, maaş alma.", action: CardAction.goToJail),
    GameCard(id: 109, deck: CardDeck.chance, text: 'Kodesten Çıkış Kartı. Gerekene kadar sakla.', action: CardAction.getOutOfJail),
    GameCard(id: 110, deck: CardDeck.chance, text: 'Hız cezası! 30M öde.', action: CardAction.pay, value: 30),
    GameCard(id: 111, deck: CardDeck.chance, text: 'Yatırımın kâr getirdi. 150M al.', action: CardAction.receive, value: 150),
    GameCard(id: 112, deck: CardDeck.chance, text: 'Belediye başkanı seçildin! Her oyuncuya 50M öde.', action: CardAction.payEach, value: 50),
    GameCard(id: 113, deck: CardDeck.chance, text: 'Binalarına bakım yap: ev başına 25M, gökdelen başına 100M öde.', action: CardAction.repairs, value: 25, value2: 100),
    GameCard(id: 114, deck: CardDeck.chance, text: "Kordon'da yürüyüş zamanı! İzmir'e ilerle.", action: CardAction.advanceTo, targetCity: 'İzmir'),
  ];

  static const List<GameCard> communityFund = [
    GameCard(id: 201, deck: CardDeck.communityFund, text: 'Banka hatası lehine! 150M al.', action: CardAction.receive, value: 150),
    GameCard(id: 202, deck: CardDeck.communityFund, text: 'Doktor masrafı. 50M öde.', action: CardAction.pay, value: 50),
    GameCard(id: 203, deck: CardDeck.communityFund, text: 'Doğum günün! Her oyuncudan 50M topla.', action: CardAction.collectFromEach, value: 50),
    GameCard(id: 204, deck: CardDeck.communityFund, text: 'Doğrudan Kodese git!', action: CardAction.goToJail),
    GameCard(id: 205, deck: CardDeck.communityFund, text: 'Kodesten Çıkış Kartı. Gerekene kadar sakla.', action: CardAction.getOutOfJail),
    GameCard(id: 206, deck: CardDeck.communityFund, text: 'Başlangıç noktasına ilerle ve maaşını al.', action: CardAction.advanceTo),
    GameCard(id: 207, deck: CardDeck.communityFund, text: 'Vergi iadesi. 40M al.', action: CardAction.receive, value: 40),
    GameCard(id: 208, deck: CardDeck.communityFund, text: 'Hastane masrafı. 100M öde.', action: CardAction.pay, value: 100),
    GameCard(id: 209, deck: CardDeck.communityFund, text: 'Hisse senedi satışı. 100M al.', action: CardAction.receive, value: 100),
    GameCard(id: 210, deck: CardDeck.communityFund, text: 'Okul harcı. 75M öde.', action: CardAction.pay, value: 75),
    GameCard(id: 211, deck: CardDeck.communityFund, text: 'Güzellik yarışmasında ikinci oldun. 20M al.', action: CardAction.receive, value: 20),
    GameCard(id: 212, deck: CardDeck.communityFund, text: 'Yol yapım katkı payı: ev başına 40M, gökdelen başına 115M öde.', action: CardAction.repairs, value: 40, value2: 115),
    GameCard(id: 213, deck: CardDeck.communityFund, text: 'Mirasa konan şanslı kişi sensin! 200M al.', action: CardAction.receive, value: 200),
  ];

  static final Map<int, GameCard> _byId = {
    for (final c in [...chance, ...communityFund]) c.id: c,
  };

  static GameCard byId(int id) {
    final card = _byId[id];
    if (card == null) throw ArgumentError('Bilinmeyen kart id: $id');
    return card;
  }

  static List<int> shuffledIds(CardDeck deck, [Random? random]) {
    final source = deck == CardDeck.chance ? chance : communityFund;
    return [for (final c in source) c.id]..shuffle(random ?? Random.secure());
  }
}

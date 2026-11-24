import '../core/utils/dice.dart';
import '../logic/game_engine.dart';
import '../models/trade_offer.dart';
import 'room_repository.dart';

/// Oyun içi hamleleri Firestore transaction'ı içinde [GameEngine] ile uygular.
class GameRepository {
  GameRepository(this._rooms, {Dice? dice}) : _dice = dice ?? Dice();

  final RoomRepository _rooms;
  final Dice _dice;

  Future<void> rollDice(String code, String uid) => _rooms.updateRoom(
      code, (r) => GameEngine.rollDice(r, uid, _dice.roll()));

  Future<void> buy(String code, String uid) =>
      _rooms.updateRoom(code, (r) => GameEngine.buyProperty(r, uid));

  Future<void> decline(String code, String uid) =>
      _rooms.updateRoom(code, (r) => GameEngine.declineProperty(r, uid));

  Future<void> acknowledgeCard(String code, String uid) =>
      _rooms.updateRoom(code, (r) => GameEngine.acknowledgeCard(r, uid));

  Future<void> buildHouse(String code, String uid, int tile) =>
      _rooms.updateRoom(code, (r) => GameEngine.buildHouse(r, uid, tile));

  Future<void> sellBuilding(String code, String uid, int tile) =>
      _rooms.updateRoom(code, (r) => GameEngine.sellBuilding(r, uid, tile));

  Future<void> mortgage(String code, String uid, int tile) =>
      _rooms.updateRoom(code, (r) => GameEngine.mortgage(r, uid, tile));

  Future<void> unmortgage(String code, String uid, int tile) =>
      _rooms.updateRoom(code, (r) => GameEngine.unmortgage(r, uid, tile));

  Future<void> payBail(String code, String uid) =>
      _rooms.updateRoom(code, (r) => GameEngine.payBail(r, uid));

  Future<void> useJailCard(String code, String uid) =>
      _rooms.updateRoom(code, (r) => GameEngine.useJailCard(r, uid));

  Future<void> endTurn(String code, String uid) =>
      _rooms.updateRoom(code, (r) => GameEngine.endTurn(r, uid));

  Future<void> declareBankruptcy(String code, String uid) =>
      _rooms.updateRoom(code, (r) => GameEngine.declareBankruptcy(r, uid));

  // ── Açık artırma ──
  static int get _now => DateTime.now().millisecondsSinceEpoch;

  Future<void> startAuction(String code, String uid, int tile, int startPrice) =>
      _rooms.updateRoom(code,
          (r) => GameEngine.startAuction(r, uid, tile, startPrice, _now));

  Future<void> placeBid(String code, String uid, int amount) =>
      _rooms.updateRoom(code, (r) => GameEngine.placeBid(r, uid, amount, _now));

  /// Süresi dolan müzayedeyi kapatır; erken çağrılırsa hiçbir şey yapmaz.
  Future<void> finalizeAuction(String code) =>
      _rooms.updateRoom(code, (r) => GameEngine.finalizeAuction(r, _now));

  /// Süre sınırı dolduysa oyunu bitirir; erken çağrılırsa hiçbir şey yapmaz.
  Future<void> finishByTime(String code) =>
      _rooms.updateRoom(code, (r) => GameEngine.finishByTime(r, _now));

  // ── Teklifler ──
  Future<void> sendOffer(String code, TradeOffer offer) =>
      _rooms.updateRoom(code, (r) => GameEngine.sendOffer(r, offer));

  Future<void> acceptOffer(String code, String uid, String offerId) =>
      _rooms.updateRoom(code, (r) => GameEngine.acceptOffer(r, uid, offerId));

  Future<void> rejectOffer(String code, String uid, String offerId) =>
      _rooms.updateRoom(code, (r) => GameEngine.rejectOffer(r, uid, offerId));
}

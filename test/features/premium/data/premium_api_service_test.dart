import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/premium/data/premium_api_service.dart';

void main() {
  group('PremiumInviteOverview', () {
    test('parses XBoard invite fetch response with numeric stat array', () {
      final overview = PremiumInviteOverview.fromJson({
        'status': 'success',
        'data': {
          'codes': [
            {'code': 'ABCD1234', 'pv': 2, 'status': 0, 'created_at': 1893456000},
          ],
          'stat': [3, 12345, 678, 20, 9900],
        },
      });

      expect(overview.codes, hasLength(1));
      expect(overview.codes.first.code, 'ABCD1234');
      expect(overview.codes.first.pv, 2);
      expect(overview.stat.registeredUserCount, 3);
      expect(overview.stat.validCommissionAmountCents, 12345);
      expect(overview.stat.pendingCommissionAmountCents, 678);
      expect(overview.stat.commissionRatePercent, 20);
      expect(overview.stat.availableCommissionBalanceCents, 9900);
    });

    test('parses named app BFF style stat fields defensively', () {
      final overview = PremiumInviteOverview.fromJson({
        'data': {
          'codes': {'data': <Object>[]},
          'stat': {
            'registered_user_count': '4',
            'valid_commission_amount_cents': '1200',
            'pending_commission_amount_cents': '300',
            'commission_rate_percent': '15',
            'available_commission_balance_cents': '900',
          },
        },
      });

      expect(overview.codes, isEmpty);
      expect(overview.stat.registeredUserCount, 4);
      expect(overview.stat.validCommissionAmountCents, 1200);
      expect(overview.stat.pendingCommissionAmountCents, 300);
      expect(overview.stat.commissionRatePercent, 15);
      expect(overview.stat.availableCommissionBalanceCents, 900);
    });
  });

  group('PremiumCommissionPage', () {
    test('parses raw invite details response', () {
      final page = PremiumCommissionPage.fromJson({
        'data': [
          {'get_amount': 500, 'order_amount': 2000, 'trade_no': 'T001', 'created_at': '2030-01-01T00:00:00Z'},
        ],
        'total': 1,
      });

      expect(page.total, 1);
      expect(page.records.single.amountCents, 500);
      expect(page.records.single.orderAmountCents, 2000);
      expect(page.records.single.tradeNo, 'T001');
      expect(page.records.single.createdAt, DateTime.parse('2030-01-01T00:00:00Z'));
    });
  });

  group('PremiumTicketSummary', () {
    test('parses XBoard ticket list response', () {
      final tickets = PremiumTicketSummary.listFromResponse({
        'status': 'success',
        'data': [
          {'id': 7, 'subject': 'APP反馈：连接问题', 'status': 0, 'reply_status': 1, 'created_at': 1893456000},
        ],
      });

      expect(tickets, hasLength(1));
      expect(tickets.single.id, 7);
      expect(tickets.single.subject, 'APP反馈：连接问题');
      expect(tickets.single.isClosed, isFalse);
      expect(tickets.single.replyStatus, 1);
    });
  });
}

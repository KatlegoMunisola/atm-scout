-- Default currency + denominations: Botswana Pula (P)
insert into currencies (code, name, symbol) values
  ('BWP', 'Botswana Pula', 'P')
on conflict (code) do nothing;

insert into denominations (currency_code, value, label, sort_order) values
  ('BWP', 10, 'P10', 1),
  ('BWP', 20, 'P20', 2),
  ('BWP', 50, 'P50', 3),
  ('BWP', 100, 'P100', 4),
  ('BWP', 200, 'P200', 5)
on conflict (currency_code, value) do nothing;

# Tạo vmos-price-ref.json (chỉ đọc) từ file HĐ VMOS cho trang Báo cáo tổng quát
import openpyxl, json, sys, collections, datetime
src, out = sys.argv[1], sys.argv[2]
wb = openpyxl.load_workbook(src, read_only=True, data_only=True)
rows = list(wb['Chi tiet vat lieu'].iter_rows(min_row=2, values_only=True))
hds = list(wb['Danh sach hop dong'].iter_rows(min_row=2, values_only=True))
FIX_PK = {'CON26013002': 'P03-D1'}   # 15 HĐ trống Gói -> gán tạm
def S(x): return '' if x is None else str(x).strip()
idx = {}
def I(tab, v):
    d = idx.setdefault(tab, {})
    if v not in d: d[v] = len(d)
    return d[v]
names = {}; R = []; zero = 0
for r in rows:
    pk = S(r[0]) or FIX_PK.get(S(r[2]), '')
    mat = S(r[10]); price = r[15] if isinstance(r[15], (int, float)) else 0
    if not mat: continue
    if price <= 0: zero += 1
    names.setdefault(mat, [S(r[12]), S(r[13]), S(r[14])])
    ok = 1 if S(r[24]) in ('Khớp tên TQ', 'Khớp tên VN') else 0
    R.append([I('k', pk), I('s', S(r[6])), I('t', S(r[7])), I('h', S(r[3])), mat, round(float(price), 4), S(r[23]), ok])
multi = collections.defaultdict(set)
for x in R:
    if x[5] > 0: multi[x[4]].add(x[5])
res = {
    'v': 1, 'src': src.split('/')[-1].split('-', 1)[-1] if '-' in src.split('/')[-1][:9] else src.split('/')[-1],
    'at': datetime.date.today().isoformat(),
    'k': list(idx['k']), 's': list(idx['s']), 't': list(idx['t']), 'h': list(idx['h']),
    'n': names, 'r': R,
    'st': {'rows': len(rows), 'hd': len(hds), 'hdNoPk': sum(1 for h in hds if not h[1]),
           'hdNoItem': sum(1 for h in hds if (h[15] or 0) == 0), 'zero': zero,
           'multiCodes': sum(1 for v in multi.values() if len(v) > 1), 'pkFixed': 'CON26013002 -> P03-D1'}}
json.dump(res, open(out, 'w', encoding='utf8'), ensure_ascii=False, separators=(',', ':'))
print(len(R), 'rows', res['st'])

import re
c = open('exercises.md', encoding='utf-8').read()
a = re.findall(r'^> \*(.+)\*', c, re.MULTILINE)
placeholder = 'Câu trả lời của bạn'
for i, x in enumerate(a, 1):
    status = 'PLACEHOLDER' if x.strip() == placeholder else 'OK'
    print(f'Câu {i}: {status}')
answered = sum(1 for x in a if x.strip() != placeholder)
print(f'\nTotal: {answered}/10')

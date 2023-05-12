#!/usr/bin/env python3
# -*- config: utf-8 -*-

import sys
import pandas

print('0,所属未定地')

df = pandas.read_excel(
        'AdminiBoundary_CD.xlsx',
        sheet_name = '行政区域コード',
        usecols = [0, 1, 2, 5],
        skiprows = [0, 1],
        names = ['code', 'prefecture', 'city', 'revision']
        ).astype({'code': int, 'prefecture': str, 'city': str, 'revision': str})

df['name'] = df['prefecture'] + df['city'].replace('nan', '')

df[df['revision'] == 'nan'].to_csv(
        sys.stdout,
        index = False,
        header = False,
        columns = ['code', 'name'])

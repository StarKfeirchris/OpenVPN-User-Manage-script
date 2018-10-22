#!/usr/bin/python
# -*- coding:utf-8 -*-

from random import randrange, sample

# 定義列表
password_list = [
'z','y','x','w','v','u','t','s','r','q','p','n','m','k','j','h','g','f','e','d','c','b','a',
'2','3','4','5','6','7','8','9','2','3','4','5','6','7','8','9',
'?','@','#','$','%','^','&','*','_','+','-','=','@','#','$','%','&','*'
'A','B','C','D','E','F','G','H','J','K','L','M','N','P','Q','R','S','T','U','V','W','X','Y','Z'
]

# 定義長度
leng=6

password = "".join(sample(password_list, leng)).replace(' ', '')
print(password)

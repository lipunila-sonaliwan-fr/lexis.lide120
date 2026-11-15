# Vérification du portage par comparaison avec SANE

Ces outils comparent la programmation du LiDE 120 par le pilote `genesys` de
SANE et par le portage Lexis+, sans scanner :

- **côté SANE**, le pilote est compilé en « mode test » : l'interface de test
  remplace l'USB. Le correctif `trace.patch` lui fait journaliser chaque
  écriture de registre, du frontal et de la mémoire (CRC-32 des données), ainsi
  que les points de contrôle (`# move_back_home`, `# led_calibration`…) ;
- **côté Lexis+**, `principal.prg --comparer` fait la même numérisation sur le
  simulateur et produit un journal au même format.

```
sh construire.sh /chemin/vers/sane-backends-1.4.0    # g++ et gcc suffisent
WDLEXISRT=/chemin/vers/wdlexisrt sh comparer.sh Color 300 8 20 30 80 50
```

Les arguments sont : mode (`Color` ou `Gray`), résolution, profondeur, puis
x, y, largeur et hauteur en millimètres.

`comparer.py` découpe les deux journaux en blocs, un par point de contrôle, et
compare pour chacun les registres écrits et les tables de pente envoyées. Les
expositions (registres 0x8a à 0x92) sont exclues de la comparaison : elles
résultent de l'étalonnage des diodes, que SANE ne fait pas en mode test.
L'ombrage est comparé en faisant lire au simulateur les mêmes données nulles
que l'interface de test de SANE.

Écarts attendus, qui ne viennent pas du pilote :

- registres 0x100 et 0x101 dans le bloc `amorcage` : initialisation propre à
  l'interface de test de SANE ;
- blocs `move_back_home` absents côté Lexis : en mode test, SANE ne voit jamais
  la tête au repos, alors que le simulateur l'y voit tout de suite ;
- registre 0x32 dans le premier bloc `feed` : écrit pendant le
  `move_back_home` qui le précède dans SANE.

---
layout: post
title: C++ Developer Academy
published: true
---
Le C++ est un langage qui évolue, particulièrement depuis ces 5 dernières années.
Il est donc important pour tout bon développeur de se tenir à jour sur les évolutions du langage et sur les bonnes pratiques associées.
Au passage, un petit coup de balai sur les anciennes et/ou mauvaises pratiques ne fait pas de mal.

<style>
img.vignette
{
    width: 150px;
    background-color: white;
    padding: 10px;
    border-radius: 25px;
    box-shadow: 0 0 30px 5px rgba(0.9, 0.9, 0.9, 0.9);
}
</style>

###<img src="/images/logo-cpp.png" class="vignette" /> Langage C++

Le langage C++ était dans le coma depuis 2003.
Le comité de standardisation s'embourbait dans des discussions sans fin sur les _Technical Report_ a intégrer dans la future version de la norme, le C++0x.
Remarquez qu'ils étaient quand même confiant sur le fait de sortir la nouvelle norme avant 2010... Raté ;-)
Le langage C++ somnolat donc dans un état végétatif... Jusqu'en 2011, ou le _reveil de la force_ eut lieu.
Et quel réveil ! Aujourd'hui, plus que jamais, le C++ est un langage adapté aux défis des applications d'aujourd'hui et de demain.
Que ce soit pour les SmartPhone, le Web ou le Cloud, le C++ tient toujours ces promesses.

###<img src="/images/yoda/death-star-training-academy.jpg" class="vignette" /> Mauvaises pratiques... Bienvenu à la _Death Star Training Academy_

Très souvent la formation des jeunes Jedi du C++ commence par la _Death Star Academy_.
On commençe par une formation scolaire, ou l'on nous enseigne les bases du langage.
Suivant notre année de naissance, on nous apprend les bases du C++11 voir du C++14 pour les plus ~~chanceux~~ jeunes.
Pour la plupart des autres, les vieux ;-), on nous a cantonné aux rudiments du C++03.
Mais dans tous les cas, on y apprend la syntaxe du langage mais en aucun cas la sémantique associée.
On nous enseigne plus ou moins finnement ce qu'est une classe, une référence, le polymorphisme ou un opérateur d'assignement par copie.
Mais on vous laisse toujours découvrir par vous-même comment utiliser correctement ces puissants outils.
Un peu comme si on offrait un katana a un enfant... Comme le disait les bandes magnétiques de Mission Impossible,
> Si vous ou l'un de vos agents étiez capturés ou tués, le Département d'État nierait avoir eu connaissance de vos agissements.
>
> Bonne chance, Jim.

Et c'est là ou l'on rejoint, consciement ou non, la _Death Star Training Academy_.
Sans être guidé du bon côté de la force, il est très facile de basculer du côté obscur.
Parfois consciement par simple faignantise ou par laxisme, souvent par ignorance, il est très facile de se laisser emporter du mauvais côté de la force.

###<img src="/images/yoda/jedi-academy.jpg" class="vignette" /> Bonnes pratiques... Bienvenu à la _Jedi Academy_

Heureusement, il est toujours possible de revenir du bon côté de la force.
Et c'est exactement l'objet de cette série de posts, _C++ Developper Academy_, de ramener les brebis égarer à la _Jedi Academy_, vers le bon côté de la force.
Ces posts poursuiveront la formation scolaire, en vous enseignant comment écopper les fuites mémoires en supprimant la plupart des `new`/`delete`, comment gérer élégament les exceptions, ...

C'est posts seront ponctués d'avertissement concernant de mauvaises pratiques qui vous feraient basculer du côté obscur :
><img src="/images/yoda/darth-vader.png" width=75px /> L'Empereur te montrera la vraie nature de la Force.

Mais surtout de bon conseils, dignes de ceux de maître Yoda :
><img src="/images/yoda/yoda.png" width=65px /> Non, n'essaie pas ! Fais-le, ou ne le fais pas ! Il n'y a pas d'essai.

Donc... Bienvenue à la _C++ Developer Academy_ ! Et commençons tout de suite par un sujet des plus importants : _La gestion de ressources_

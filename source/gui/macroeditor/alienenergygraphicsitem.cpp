#include "alienenergygraphicsitem.h"

#include "gui/editorsettings.h"

#include <QPainter>

EnergyGraphicsItem::EnergyGraphicsItem (QGraphicsItem* parent)
    : QGraphicsItem(parent), _e(0), _focusState(NO_FOCUS)
{
    QGraphicsItem::setPos(0.0, 0.0);
}

EnergyGraphicsItem::EnergyGraphicsItem (EnergyParticle* e, qreal x, qreal y, QGraphicsItem* parent)
    : QGraphicsItem(parent), _e(e), _focusState(NO_FOCUS)
{
    QGraphicsItem::setPos(x, y);
}

EnergyGraphicsItem::~EnergyGraphicsItem ()
{
}

QRectF EnergyGraphicsItem::boundingRect () const
{
    return QRectF(-0.4, -0.4, 0.8, 0.8);
}

void EnergyGraphicsItem::paint (QPainter *painter, const QStyleOptionGraphicsItem *option, QWidget *widget)
{
    if( _focusState == NO_FOCUS ) {
        painter->setPen(QPen(QBrush(QColor(0,0,0,0)), 0.03));
        painter->setBrush(QBrush(ENERGY_COLOR));
        painter->drawEllipse(QPointF(0.0, 0.0), 0.20, 0.20);
    }
    else {
        painter->setPen(QPen(QBrush(ENERGY_PEN_FOCUS_COLOR), 0.03));
        painter->setBrush(QBrush(ENERGY_FOCUS_COLOR));
        painter->drawEllipse(QPointF(0.0, 0.0), 0.4, 0.4);
    }
}

int EnergyGraphicsItem::type() const
{
    return Type;
}

void EnergyGraphicsItem::setFocusState (FocusState focusState)
{
    _focusState = focusState;
}

EnergyParticle* EnergyGraphicsItem::getEnergyParticle ()
{
    return _e;
}




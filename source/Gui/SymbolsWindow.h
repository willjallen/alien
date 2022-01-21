#pragma once

#include "EngineInterface/Definitions.h"

#include "AlienWindow.h"
#include "Definitions.h"

class _SymbolsWindow : public _AlienWindow
{
public:
    _SymbolsWindow(SimulationController const& simController);

private:
    void processIntern() override;

    enum class SymbolType {
        Variable, Constant
    };
    struct Entry {
        std::string name;
        SymbolType type;
        std::string value;
    };
    std::vector<Entry> getEntriesFromSymbolMap() const;
    void updateSymbolMapFromEntries(std::vector<Entry> const& entries);

    bool isEditValid() const;

    void onClearEditFields();
    void onEditEntry(Entry const& entry);
    void onAddEntry(std::vector<Entry>& entries, std::string const& name, std::string const& value) const;
    void onUpdateEntry(std::vector<Entry>& entries, std::string const& name, std::string const& value) const;
    void onDeleteEntry(std::vector<Entry>& entries, std::string const& name) const;

    std::string _origSymbolName;
    char _symbolName[256];
    char _symbolValue[256];

    SimulationController _simController;

    enum class Mode
    {
        Edit, Create
    };
    Mode _mode = Mode::Create;
};
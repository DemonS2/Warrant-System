const { createApp } = Vue;

createApp({
    data() {
        return {
            currentScreen: 'main',
            activeTab: 'search',
            searchTerm: '',
            searchResults: [],
            warrants: [],
            newWarrant: {
                name: '',
                citizenid: '',
                reason: '',
                evidence: '',
                bounty: 0,
                expiry: 0
            },
            warrantData: {},
            evidence: '',
            tabletVisible: false
        }
    },
    methods: {
        closeTablet() {
            this.tabletVisible = false;
            fetch(`https://${GetParentResourceName()}/CloseTablet`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({})
            }).catch(error => {
                console.error('Close tablet error:', error);
            });
        },
        
        searchWarrants() {
            if (!this.searchTerm.trim()) {
                this.showNotification('Please enter a search term', 'error');
                return;
            }
            
            fetch(`https://${GetParentResourceName()}/SearchWarrants`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    searchTerm: this.searchTerm
                })
            })
            .then(response => response.json())
            .then(data => {
                this.searchResults = data;
                if (data.length === 0) {
                    this.showNotification('No warrants found for: ' + this.searchTerm, 'info');
                }
            })
            .catch(error => {
                console.error('Search error:', error);
                this.showNotification('Search failed', 'error');
            });
        },
        
        loadAllWarrants() {
            this.activeTab = 'all';
            fetch(`https://${GetParentResourceName()}/GetAllWarrants`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                }
            }).catch(error => {
                console.error('Load all warrants error:', error);
            });
        },
        
        revokeWarrant(warrantId) {
            if (confirm('Are you sure you want to revoke warrant #' + warrantId + '?')) {
                fetch(`https://${GetParentResourceName()}/RevokeWarrant`, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({
                        warrantId: warrantId
                    })
                }).then(() => {
                    // Remove from local lists
                    this.searchResults = this.searchResults.filter(w => w.id !== warrantId);
                    this.warrants = this.warrants.filter(w => w.id !== warrantId);
                    this.showNotification('Warrant revoked successfully', 'success');
                }).catch(error => {
                    console.error('Revoke error:', error);
                    this.showNotification('Failed to revoke warrant', 'error');
                });
            }
        },
        
        issueWarrant() {
            if (!this.newWarrant.name || !this.newWarrant.reason) {
                this.showNotification('Please fill in suspect name and reason', 'error');
                return;
            }
            
            this.warrantData = { ...this.newWarrant };
            this.currentScreen = 'evidence';
        },
        
        confirmIssue() {
            if (!this.evidence.trim()) {
                this.showNotification('Please provide evidence', 'error');
                return;
            }

            const warrantData = {
                ...this.warrantData,
                evidence: this.evidence
            };
            
            fetch(`https://${GetParentResourceName()}/CreateWarrant`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(warrantData)
            }).then(response => {
                if (response.ok) {
                    this.showNotification('Warrant issued successfully!', 'success');
                    this.cancelIssue();
                } else {
                    this.showNotification('Failed to issue warrant', 'error');
                }
            }).catch(error => {
                console.error('Issue warrant error:', error);
                this.showNotification('Failed to issue warrant', 'error');
            });
        },
        
        cancelIssue() {
            this.currentScreen = 'main';
            this.activeTab = 'issue';
            this.evidence = '';
            this.warrantData = {};
            // Reset form
            this.newWarrant = {
                name: '',
                citizenid: '',
                reason: '',
                evidence: '',
                bounty: 0,
                expiry: 0
            };
        },
        
        formatDate(dateString) {
            if (!dateString) return 'Never';
            try {
                const date = new Date(dateString);
                return date.toLocaleDateString() + ' ' + date.toLocaleTimeString();
            } catch (e) {
                return 'Invalid Date';
            }
        },
        
        showNotification(message, type) {
            // This would ideally trigger a QBCore notification
            // For now, we'll use alert for important messages
            if (type === 'error') {
                alert('ERROR: ' + message);
            }
        }
    },
    
    mounted() {
        // Initially hide the tablet
        this.tabletVisible = false;
        
        // Listen for messages from the game
        window.addEventListener('message', (event) => {
            const data = event.data;
            
            if (data.action === 'showTablet') {
                this.tabletVisible = true;
                this.currentScreen = 'main';
                this.activeTab = 'search';
                document.body.classList.add('visible');
            }
            else if (data.action === 'hideTablet') {
                this.tabletVisible = false;
                this.currentScreen = 'main';
                document.body.classList.remove('visible');
            }
            else if (data.action === 'showEvidenceInput') {
                this.warrantData = data;
                this.currentScreen = 'evidence';
                this.tabletVisible = true;
                document.body.classList.add('visible');
            }
            else if (data.action === 'showWarrantResults') {
                this.searchResults = data.warrants;
                this.currentScreen = 'main';
                this.activeTab = 'search';
                this.tabletVisible = true;
                document.body.classList.add('visible');
            }
            else if (data.action === 'showAllWarrants') {
                this.warrants = data.warrants;
                this.currentScreen = 'main';
                this.activeTab = 'all';
                this.tabletVisible = true;
                document.body.classList.add('visible');
            }
        });

        // Close on ESC key
        document.addEventListener('keydown', (event) => {
            if (event.key === 'Escape' && this.tabletVisible) {
                this.closeTablet();
            }
        });
        
        // Prevent right-click context menu
        document.addEventListener('contextmenu', (event) => {
            event.preventDefault();
            return false;
        });
    }
}).mount('#app');
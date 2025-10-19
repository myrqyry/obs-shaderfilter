// BeatForge Studio - Application Logic

// Application State
const appState = {
    currentSection: 'dashboard',
    currentTheme: 'cyberpunk',
    trainingProgress: {
        epochs: 45,
        totalEpochs: 100,
        loss: 0.0234,
        accuracy: 94.2
    },
    processingQueue: [
        {
            name: 'Electronic Dreams',
            genre: 'Electronic',
            duration: '3:42',
            bpm: 128,
            size: '8.2 MB',
            status: 'processed',
            progress: 100
        },
        {
            name: 'Neon Nights',
            genre: 'Synthwave',
            duration: '4:15',
            bpm: 140,
            size: '9.8 MB',
            status: 'processing',
            progress: 67
        },
        {
            name: 'Digital Pulse',
            genre: 'Drum & Bass',
            duration: '3:28',
            bpm: 174,
            size: '7.9 MB',
            status: 'queued',
            progress: 0
        }
    ],
    beatmaps: [
        {
            name: 'Electronic Dreams',
            difficulty: 'Expert',
            rating: 4.7,
            plays: 1247,
            likes: 892,
            stars: 5
        },
        {
            name: 'Neon Nights',
            difficulty: 'Hard',
            rating: 4.3,
            plays: 834,
            likes: 621,
            stars: 4
        },
        {
            name: 'Digital Pulse',
            difficulty: 'Expert+',
            rating: 4.9,
            plays: 2103,
            likes: 1876,
            stars: 5
        }
    ]
};

// Theme Management
const themes = {
    cyberpunk: {
        primary: '#00d4ff',
        accent: '#ff0080',
        primaryHover: '#00b8e6',
        accentHover: '#e6006b'
    },
    minimal: {
        primary: '#8b5cf6',
        accent: '#10b981',
        primaryHover: '#7c3aed',
        accentHover: '#059669'
    },
    electric: {
        primary: '#facc15',
        accent: '#f59e0b',
        primaryHover: '#eab308',
        accentHover: '#d97706'
    },
    'deep-space': {
        primary: '#3b82f6',
        accent: '#1d4ed8',
        primaryHover: '#2563eb',
        accentHover: '#1e40af'
    }
};

// Charts
let trainingChart = null;
let trainingMetricsChart = null;

// Initialize Application
document.addEventListener('DOMContentLoaded', function() {
    initializeNavigation();
    initializeThemeSelector();
    initializeUploadHandlers();
    initializeTabs();
    initializeRatingSystem();
    initializeCharts();
    
    // Start training progress simulation
    simulateTrainingProgress();
});

// Navigation System
function initializeNavigation() {
    const navItems = document.querySelectorAll('.nav-item');
    const sections = document.querySelectorAll('.section');
    const sectionTitle = document.getElementById('current-section-title');
    
    navItems.forEach(item => {
        item.addEventListener('click', function(e) {
            e.preventDefault();
            
            const targetSection = this.getAttribute('data-section');
            
            // Update active nav item
            navItems.forEach(nav => nav.classList.remove('active'));
            this.classList.add('active');
            
            // Update active section
            sections.forEach(section => section.classList.remove('active'));
            document.getElementById(targetSection).classList.add('active');
            
            // Update section title
            sectionTitle.textContent = this.querySelector('span').textContent;
            
            appState.currentSection = targetSection;
        });
    });
}

// Theme System
function initializeThemeSelector() {
    const themeSelector = document.getElementById('theme-selector');
    const themePreviewsParent = document.querySelector('[data-tab="appearance"]');
    
    themeSelector.addEventListener('change', function() {
        const selectedTheme = this.value;
        applyTheme(selectedTheme);
    });
    
    // Handle theme preview clicks
    if (themePreviewsParent) {
        themePreviewsParent.addEventListener('click', function(e) {
            const themePreview = e.target.closest('.theme-preview');
            if (themePreview) {
                const theme = themePreview.getAttribute('data-theme');
                applyTheme(theme);
                
                // Update selector
                themeSelector.value = theme;
                
                // Update visual selection
                const allPreviews = themePreviewsParent.querySelectorAll('.theme-preview');
                allPreviews.forEach(preview => {
                    preview.style.borderColor = 'var(--studio-border)';
                });
                themePreview.style.borderColor = 'var(--theme-primary)';
            }
        });
    }
}

function applyTheme(themeName) {
    const theme = themes[themeName];
    if (!theme) return;
    
    const root = document.documentElement;
    const bodyClasses = document.body.classList;
    
    // Remove existing theme classes
    bodyClasses.remove('theme-cyberpunk', 'theme-minimal', 'theme-electric', 'theme-deep-space');
    
    // Add new theme class
    bodyClasses.add(`theme-${themeName}`);
    
    // Update CSS variables
    root.style.setProperty('--theme-primary', theme.primary);
    root.style.setProperty('--theme-accent', theme.accent);
    root.style.setProperty('--theme-primary-hover', theme.primaryHover);
    root.style.setProperty('--theme-accent-hover', theme.accentHover);
    
    appState.currentTheme = themeName;
    
    // Update chart colors if they exist
    if (trainingChart) {
        updateChartColors(trainingChart, theme.primary, theme.accent);
    }
    if (trainingMetricsChart) {
        updateChartColors(trainingMetricsChart, theme.primary, theme.accent);
    }
}

// File Upload System
function initializeUploadHandlers() {
    const uploadArea = document.getElementById('upload-area');
    const fileInput = document.getElementById('file-input');
    
    if (uploadArea) {
        uploadArea.addEventListener('dragover', function(e) {
            e.preventDefault();
            this.classList.add('dragover');
        });
        
        uploadArea.addEventListener('dragleave', function(e) {
            e.preventDefault();
            this.classList.remove('dragover');
        });
        
        uploadArea.addEventListener('drop', function(e) {
            e.preventDefault();
            this.classList.remove('dragover');
            
            const files = e.dataTransfer.files;
            handleFileUpload(files);
        });
    }
    
    if (fileInput) {
        fileInput.addEventListener('change', function(e) {
            handleFileUpload(e.target.files);
        });
    }
}

function handleFileUpload(files) {
    Array.from(files).forEach(file => {
        // Simulate file processing
        const newItem = {
            name: file.name.replace(/\.[^/.]+$/, ""),
            genre: 'Unknown',
            duration: '0:00',
            bpm: 0,
            size: formatFileSize(file.size),
            status: 'processing',
            progress: 0
        };
        
        appState.processingQueue.push(newItem);
        updateProcessingQueue();
        
        // Simulate processing
        simulateProcessing(newItem);
    });
}

function formatFileSize(bytes) {
    if (bytes === 0) return '0 Bytes';
    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + ' ' + sizes[i];
}

// Tab System
function initializeTabs() {
    const tabButtons = document.querySelectorAll('.tab-button');
    const tabContents = document.querySelectorAll('.tab-content');
    
    tabButtons.forEach(button => {
        button.addEventListener('click', function() {
            const targetTab = this.getAttribute('data-tab');
            const parentContainer = this.closest('.tab-container');
            
            // Update tab buttons
            parentContainer.querySelectorAll('.tab-button').forEach(btn => {
                btn.classList.remove('active');
            });
            this.classList.add('active');
            
            // Update tab content
            parentContainer.querySelectorAll('.tab-content').forEach(content => {
                content.classList.remove('active');
            });
            const targetContent = document.getElementById(targetTab);
            if (targetContent) {
                targetContent.classList.add('active');
            }
        });
    });
}

// Rating System
function initializeRatingSystem() {
    document.addEventListener('click', function(e) {
        if (e.target.classList.contains('rating-star')) {
            const rating = parseInt(e.target.getAttribute('data-rating'));
            const ratingContainer = e.target.parentElement;
            const stars = ratingContainer.querySelectorAll('.rating-star');
            
            stars.forEach((star, index) => {
                if (index < rating) {
                    star.classList.add('active');
                } else {
                    star.classList.remove('active');
                }
            });
            
            // Store rating in container
            ratingContainer.setAttribute('data-rating', rating);
        }
    });
}

// Modal System
function openRatingModal(beatmapName) {
    const modal = document.getElementById('rating-modal');
    const nameElement = document.getElementById('rating-beatmap-name');
    
    nameElement.textContent = beatmapName;
    modal.style.display = 'flex';
    
    // Reset all ratings
    const ratingContainers = modal.querySelectorAll('.rating-stars');
    ratingContainers.forEach(container => {
        container.querySelectorAll('.rating-star').forEach(star => {
            star.classList.remove('active');
        });
        container.removeAttribute('data-rating');
    });
}

function closeRatingModal() {
    const modal = document.getElementById('rating-modal');
    modal.style.display = 'none';
}

function submitRating() {
    const modal = document.getElementById('rating-modal');
    const beatmapName = document.getElementById('rating-beatmap-name').textContent;
    const comment = modal.querySelector('textarea').value;
    
    // Collect ratings
    const ratings = {};
    const ratingContainers = modal.querySelectorAll('.rating-stars');
    ratingContainers.forEach(container => {
        const rating = container.getAttribute('data-rating');
        const id = container.id.replace('-rating', '');
        ratings[id] = rating ? parseInt(rating) : 0;
    });
    
    console.log('Rating submitted for:', beatmapName);
    console.log('Ratings:', ratings);
    console.log('Comment:', comment);
    
    // Close modal
    closeRatingModal();
    
    // Show success message (you could implement a toast notification here)
    alert('Rating submitted successfully!');
}

// Charts
function initializeCharts() {
    initializeTrainingChart();
    initializeTrainingMetricsChart();
}

function initializeTrainingChart() {
    const ctx = document.getElementById('training-chart');
    if (!ctx) return;
    
    const theme = themes[appState.currentTheme];
    
    trainingChart = new Chart(ctx, {
        type: 'line',
        data: {
            labels: Array.from({length: 45}, (_, i) => `Epoch ${i + 1}`),
            datasets: [{
                label: 'Training Loss',
                data: generateTrainingData(45, 0.8, 0.02),
                borderColor: theme.primary,
                backgroundColor: theme.primary + '20',
                tension: 0.4,
                fill: true
            }, {
                label: 'Validation Loss',
                data: generateTrainingData(45, 0.85, 0.025),
                borderColor: theme.accent,
                backgroundColor: theme.accent + '20',
                tension: 0.4,
                fill: false
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: {
                    labels: {
                        color: '#b0b0b0'
                    }
                }
            },
            scales: {
                x: {
                    ticks: {
                        color: '#888',
                        maxTicksLimit: 10
                    },
                    grid: {
                        color: '#333'
                    }
                },
                y: {
                    ticks: {
                        color: '#888'
                    },
                    grid: {
                        color: '#333'
                    }
                }
            }
        }
    });
}

function initializeTrainingMetricsChart() {
    const ctx = document.getElementById('training-metrics-chart');
    if (!ctx) return;
    
    const theme = themes[appState.currentTheme];
    
    trainingMetricsChart = new Chart(ctx, {
        type: 'doughnut',
        data: {
            labels: ['Training Accuracy', 'Validation Accuracy', 'Remaining'],
            datasets: [{
                data: [94.2, 92.8, 7.2],
                backgroundColor: [theme.primary, theme.accent, '#333'],
                borderWidth: 0
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: {
                    position: 'bottom',
                    labels: {
                        color: '#b0b0b0',
                        padding: 20
                    }
                }
            },
            cutout: '70%'
        }
    });
}

function generateTrainingData(epochs, start, end) {
    const data = [];
    for (let i = 0; i < epochs; i++) {
        const progress = i / epochs;
        const value = start - (start - end) * Math.pow(progress, 1.5) + (Math.random() - 0.5) * 0.05;
        data.push(Math.max(0, value));
    }
    return data;
}

function updateChartColors(chart, primary, accent) {
    if (chart.data.datasets) {
        chart.data.datasets.forEach((dataset, index) => {
            if (index === 0) {
                dataset.borderColor = primary;
                dataset.backgroundColor = primary + '20';
            } else if (index === 1) {
                dataset.borderColor = accent;
                dataset.backgroundColor = accent + '20';
            }
        });
        chart.update();
    }
}

// Processing Simulation
function simulateProcessing(item) {
    const interval = setInterval(() => {
        item.progress += Math.random() * 10;
        if (item.progress >= 100) {
            item.progress = 100;
            item.status = 'processed';
            clearInterval(interval);
        }
        updateProcessingQueue();
    }, 1000);
}

function updateProcessingQueue() {
    const tbody = document.getElementById('processing-queue');
    if (!tbody) return;
    
    tbody.innerHTML = appState.processingQueue.map(item => `
        <tr>
            <td>
                <div>
                    <div style="font-weight: var(--font-weight-medium);">${item.name}</div>
                    <div style="font-size: var(--font-size-xs); color: var(--studio-text-secondary);">${item.genre} • ${item.size}</div>
                </div>
            </td>
            <td>${item.duration}</td>
            <td>${item.bpm}</td>
            <td><span class="status-badge status-badge--${getStatusClass(item.status)}">${capitalizeFirst(item.status)}</span></td>
            <td>
                <div class="progress-bar">
                    <div class="progress-fill" style="width: ${item.progress}%;"></div>
                </div>
            </td>
            <td>
                <button class="studio-btn studio-btn--secondary">
                    <i class="fas fa-${getActionIcon(item.status)}"></i>
                </button>
            </td>
        </tr>
    `).join('');
}

function getStatusClass(status) {
    const classes = {
        'processed': 'success',
        'processing': 'processing',
        'queued': 'warning',
        'error': 'error'
    };
    return classes[status] || 'info';
}

function getActionIcon(status) {
    const icons = {
        'processed': 'download',
        'processing': 'pause',
        'queued': 'play',
        'error': 'redo'
    };
    return icons[status] || 'play';
}

function capitalizeFirst(str) {
    return str.charAt(0).toUpperCase() + str.slice(1);
}

// Training Progress Simulation
function simulateTrainingProgress() {
    setInterval(() => {
        if (appState.trainingProgress.epochs < appState.trainingProgress.totalEpochs) {
            // Occasionally advance epoch
            if (Math.random() < 0.1) {
                appState.trainingProgress.epochs++;
                appState.trainingProgress.loss *= 0.995; // Gradually decrease loss
                appState.trainingProgress.accuracy += Math.random() * 0.1; // Slight accuracy improvement
                
                // Update training chart
                if (trainingChart && appState.currentSection === 'dashboard') {
                    const newEpoch = appState.trainingProgress.epochs;
                    trainingChart.data.labels.push(`Epoch ${newEpoch}`);
                    trainingChart.data.datasets[0].data.push(appState.trainingProgress.loss);
                    trainingChart.data.datasets[1].data.push(appState.trainingProgress.loss * 1.1);
                    trainingChart.update();
                }
            }
        }
    }, 2000);
}

// Utility Functions
function showNotification(message, type = 'info') {
    // Simple notification system - could be enhanced with a proper toast library
    console.log(`[${type.toUpperCase()}] ${message}`);
}

// Export functions for global access
window.openRatingModal = openRatingModal;
window.closeRatingModal = closeRatingModal;
window.submitRating = submitRating;